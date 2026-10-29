import BackgroundTasks
import Foundation
import OSLog
import RudolstadtCore
import UserNotifications

protocol NewsFetching {
    func fetchNews() async throws -> [APINewsItem]
}

protocol NewsCaching {
    func deleteCachedNews() -> Bool
    func loadNewsFromFile() -> FileLoadingResult<[NewsItem]>
    func loadBundledNewsBackup() -> FileLoadingResult<[NewsItem]>
    func storeAPINewsToFile(news: [APINewsItem], fileName: String) -> Bool
    func isFileOlderThan(fileName: String, date: Date?) -> Bool
}

extension NewsCaching {
    func deleteCachedNews() -> Bool { false }
}

protocol NewsNotifying {
    func notifyUser(of item: NewsItem) async throws
}

enum NewsNotificationPayload {
    static let newsItemIDKey = "newsItemID"

    static func itemID(userInfo: [AnyHashable: Any], identifier: String) -> Int? {
        let id =
            (userInfo[newsItemIDKey] as? Int)
            ?? (userInfo[newsItemIDKey] as? String).flatMap(Int.init)
            ?? Int(identifier)
        return id.flatMap { $0 > 0 ? $0 : nil }
    }

    static func route(userInfo: [AnyHashable: Any], identifier: String) -> FestivalRoute? {
        if userInfo["festivalID"] != nil || userInfo["editionID"] != nil {
            guard let festival = userInfo["festivalID"] as? String, !festival.isEmpty,
                  let edition = userInfo["editionID"] as? String, !edition.isEmpty else { return nil }
            let id = (userInfo[newsItemIDKey] as? String) ?? (userInfo[newsItemIDKey] as? Int).map(String.init)
            guard let id, !id.isEmpty else { return nil }
            return FestivalRoute(identity: FestivalIdentity(festivalID: festival, editionID: edition), destination: .news(id))
        }
        // Only notifications from the original app lacked a festival identity.
        return itemID(userInfo: userInfo, identifier: identifier).map {
            FestivalRoute(identity: FestivalEdition.current.identity, destination: .news(String($0)))
        }
    }

    @MainActor
    static func request(for item: NewsItem) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = item.formattedShortDescription
        content.body = item.formattedLongDescription
        content.sound = .default
        let identity = FestivalEdition.current.identity
        content.userInfo = [newsItemIDKey: item.id, "festivalID": identity.festivalID, "editionID": identity.editionID]
        return UNNotificationRequest(identifier: identity.storageKey + "/news/" + String(item.id), content: content, trigger: nil)
    }
}

@MainActor
final class NotificationPermissionController: ObservableObject {
    static let shared = NotificationPermissionController()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let notificationCenter: UNUserNotificationCenter

    private init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    func refreshAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await refreshAuthorizationStatus()
            return granted
        } catch {
            AppLog.news.error(
                "Notification authorization failed: \(error.localizedDescription, privacy: .public)"
            )
            await refreshAuthorizationStatus()
            return false
        }
    }

    static func shouldPresentPrePrompt(
        authorizationStatus: UNAuthorizationStatus,
        promptState: NotificationPromptState
    ) -> Bool {
        authorizationStatus == .notDetermined && promptState == .notPresented
    }
}

@MainActor
final class NewsNotificationNavigationController: ObservableObject {
    static let shared = NewsNotificationNavigationController()

    @Published private(set) var requestedNewsItemID: Int?
    @Published private(set) var requestedRoute: FestivalRoute?

    init() {}

    func requestOpeningNewsItem(id: Int) {
        requestedNewsItemID = id
        requestedRoute = FestivalRoute(identity: FestivalEdition.current.identity, destination: .news(String(id)))
    }

    func requestOpeningNewsItem(from response: UNNotificationResponse) {
        let request = response.notification.request
        guard let route = NewsNotificationPayload.route(userInfo: request.content.userInfo, identifier: request.identifier) else { return }
        requestedRoute = route
        if case .news(let id) = route.destination { requestedNewsItemID = Int(id) }
    }

    func clearRequestedRoute() {
        requestedRoute = nil
        requestedNewsItemID = nil
    }

    func clearRequestedNewsItem(id: Int) {
        guard requestedNewsItemID == id else {
            return
        }
        requestedNewsItemID = nil
        requestedRoute = nil
    }
}

extension APIClient: NewsFetching {}
extension DataLoader: NewsCaching {}

final class UserNotificationNewsNotifier: NewsNotifying {
    @MainActor
    func notifyUser(of item: NewsItem) async throws {
        try await UNUserNotificationCenter.current().add(NewsNotificationPayload.request(for: item))
    }
}

enum NewsSource {
    case remote, cache, bundle, screenshot
}

enum NewsNotice: String {
    case refreshFailed = "news.refresh.failed"
    case storageFailed = "news.storage.failed"
    case bundledAfterFailure = "news.refresh.bundle"
}

@MainActor
final class NewsService {
    private let dataLoader: NewsCaching
    private let apiClient: NewsFetching
    private let userSettings: UserSettings
    private let notifier: NewsNotifying
    private let calendar: Calendar
    private let locale: Locale
    private let now: () -> Date

    init(
        dataLoader: NewsCaching,
        apiClient: NewsFetching,
        userSettings: UserSettings,
        notifier: NewsNotifying = UserNotificationNewsNotifier(),
        calendar: Calendar = .current,
        locale: Locale = .current,
        now: @escaping () -> Date = { .now }
    ) {
        self.dataLoader = dataLoader
        self.apiClient = apiClient
        self.userSettings = userSettings
        self.notifier = notifier
        self.calendar = calendar
        self.locale = locale
        self.now = now
    }

    convenience init(userSettings: UserSettings) {
        let cacheURL = try! FileManager.default.url(
            for: .cachesDirectory,
            in: .allDomainsMask,
            appropriateFor: nil,
            create: false
        )
        self.init(
            dataLoader: DataLoader(cacheURL: cacheURL),
            apiClient: APIClient(),
            userSettings: userSettings
        )
    }

    let viewModel = NewsViewModel(
        festivalID: FestivalEdition.current.identity.festivalID,
        editionID: FestivalEdition.current.identity.editionID)
    var source: NewsSource? { viewModel.current.source.flatMap(NewsSource.init(core:)) }
    var notice: NewsNotice? { viewModel.current.notice.flatMap(NewsNotice.init(rawValue:)) }
    private var latestResult: LoadingResult<[NewsItem]>? {
        switch viewModel.current.phase {
        case .ready: return .success(viewModel.current.items)
        case .failed: return .failure(.apiNotResponding)
        default: return nil
        }
    }
    private var refreshTask: Task<LoadingResult<[NewsItem]>, Never>?

    func loadCachedNews() -> [NewsItem]? {
        if case .success(let items) = latestResult {
            return items
        }
        switch dataLoader.loadNewsFromFile() {
        case .loaded(let items), .stale(let items):
            let items = uniqueNews(items)
            initializeBaseline(with: items)
            viewModel.cached(items: items)
            return items
        case .notFound, .unparsable:
            return nil
        }
    }

    func refreshNewsIfNecessary() async -> LoadingResult<[NewsItem]> {
        let result = await refreshNews(inBackground: false)
        if !Task.isCancelled, case .success(let items) = result {
            remember(items.map(\.id))
        }
        return result
    }

    func refreshNewsInBackground() async {
        _ = await refreshNews(inBackground: true)
    }

    private func refreshNews(inBackground: Bool) async -> LoadingResult<[NewsItem]> {
        guard !Task.isCancelled else { return availableNews() }
        _ = loadCachedNews()
        let freshDisk = !dataLoader.isFileOlderThan(
            fileName: "news.json",
            date: calendar.date(byAdding: .minute, value: -3, to: now()))
        switch viewModel.begin(
            background: inBackground, now: now().timeIntervalSince1970, freshDisk: freshDisk)
        {
        case .available: return latestResult ?? availableNews()
        case .reuse: return await refreshTask?.value ?? availableNews()
        default: break
        }
        let task = Task { await performRefresh() }
        refreshTask = task
        let result = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        refreshTask = nil
        viewModel.finished()
        return result
    }

    func deleteNewsCache() async -> Bool {
        guard viewModel.beginDelete() else { return false }
        let task = refreshTask
        task?.cancel()
        _ = await task?.value
        let deleted = dataLoader.deleteCachedNews()
        viewModel.endDelete(deleted: deleted)
        if deleted { refreshTask = nil }
        return deleted
    }

    private func performRefresh() async -> LoadingResult<[NewsItem]> {
        do {
            let apiNews = try await apiClient.fetchNews()
            try Task.checkCancellation()
            let history = userSettings.newsHistory.current
            let stored = dataLoader.storeAPINewsToFile(news: apiNews, fileName: "news.json")
            let delivery = viewModel.downloadedRecords(
                records: apiNews, stored: stored, history: userSettings.newsHistory,
                language: locale.appLanguageCodeIdentifier == "de" ? "de" : "en")
            if history !== userSettings.newsHistory.current {
                userSettings.persistNewsHistory(change: .oldNewsState)
            }
            await notifyAboutNewItems(delivery.notifications)
            let items = delivery.items
            return .success(items)
        } catch {
            if Task.isCancelled || error is CancellationError {
                return latestResult ?? availableNews()
            }
            AppLog.news.error(
                "News refresh failed: \(error.localizedDescription, privacy: .public)")
            let result = availableNews()
            viewModel.failed()
            return result
        }
    }

    /// Keep a successful download in memory even when its offline write failed.
    private func availableNews() -> LoadingResult<[NewsItem]> {
        if case .success = latestResult, let latestResult { return latestResult }
        if let items = loadCachedNews() { return .success(items) }
        switch dataLoader.loadBundledNewsBackup() {
        case .loaded(let items), .stale(let items):
            let items = uniqueNews(items)
            initializeBaseline(with: items)
            viewModel.bundled(items: items)
            return .success(items)
        case .notFound, .unparsable:
            return .failure(.apiNotResponding)
        }
    }

    @discardableResult
    private func initializeBaseline(with items: [NewsItem]) -> Bool {
        let old = userSettings.newsHistory.current
        let result = userSettings.newsHistory.initialize(items: items)
        if old !== userSettings.newsHistory.current { userSettings.persistNewsHistory(change: .oldNewsState) }
        return result
    }
    private func remember(_ ids: [Int]) {
        let old = userSettings.newsHistory.current.known
        userSettings.newsHistory.remember(ids: KotlinCore.ids(ids))
        if old != userSettings.newsHistory.current.known {
            userSettings.persistNewsHistory(change: .oldNewsState)
        }
    }
    private func uniqueNews(_ items: [NewsItem]) -> [NewsItem] { viewModel.unique(items: items) }

    private func notifyAboutNewItems(_ items: [NewsItem]) async {
        for item in items {
            guard !Task.isCancelled else { return }
            if !userSettings.newsHistory.notificationEligible(
                item: item,
                language: locale.appLanguageCodeIdentifier == "de" ? "de" : "en",
                foreground: viewModel.foregroundRequested)
            {
                remember([item.id])
                continue
            }
            do {
                try await notifier.notifyUser(of: item)
                // Successful system handoff counts even if cancellation arrived during it.
                remember([item.id])
            } catch {
                AppLog.news.error(
                    "Failed to notify user about news item \(item.id): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}

final class NewsRefresher {
    private let newsService: NewsService

    init(newsService: NewsService) {
        self.newsService = newsService
    }

    static func scheduleNextBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: "updateNews")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)  // 30 min
        do {
            try BGTaskScheduler.shared.submit(request)
            AppLog.news.info("Scheduled next background news refresh task")
        } catch {
            AppLog.news.error(
                "Failed to schedule background news refresh task: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Handle the task that the system launches.
    func handle() async {
        AppLog.news.info("Handling background news refresh task")
        NewsRefresher.scheduleNextBackgroundTask()
        await newsService.refreshNewsInBackground()
        AppLog.news.info("Finished background news refresh task")
    }
}
