import BackgroundTasks
import Foundation
import OSLog
import UserNotifications

protocol NewsFetching {
    func fetchNews() async throws -> [APINewsItem]
}

protocol NewsCaching {
    func loadNewsFromFile() -> FileLoadingResult<[NewsItem]>
    func loadBundledNewsBackup() -> FileLoadingResult<[NewsItem]>
    func storeAPINewsToFile(news: [APINewsItem], fileName: String) -> Bool
    func isFileOlderThan(fileName: String, date: Date?) -> Bool
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

    @MainActor
    static func request(for item: NewsItem) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = item.formattedShortDescription
        content.body = item.formattedLongDescription
        content.sound = .default
        content.userInfo = [newsItemIDKey: item.id]
        return UNNotificationRequest(identifier: String(item.id), content: content, trigger: nil)
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

    init() {}

    func requestOpeningNewsItem(id: Int) {
        requestedNewsItemID = id
    }

    func requestOpeningNewsItem(from response: UNNotificationResponse) {
        let request = response.notification.request
        if let id = NewsNotificationPayload.itemID(
            userInfo: request.content.userInfo,
            identifier: request.identifier
        ) {
            requestOpeningNewsItem(id: id)
        }
    }

    func clearRequestedNewsItem(id: Int) {
        guard requestedNewsItemID == id else {
            return
        }
        requestedNewsItemID = nil
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

    private(set) var source: NewsSource?
    private(set) var notice: NewsNotice?
    private var latestResult: LoadingResult<[NewsItem]>?
    private var lastAttempt: Date?
    private var refreshTask: Task<LoadingResult<[NewsItem]>, Never>?
    private var foregroundRefreshRequested = false

    func loadCachedNews() -> [NewsItem]? {
        if case .success(let items) = latestResult {
            return items
        }
        switch dataLoader.loadNewsFromFile() {
        case .loaded(let items), .stale(let items):
            let items = uniqueNews(items)
            initializeBaseline(with: items)
            source = .cache
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
        if let refreshTask {
            // A foreground request also makes the shared result a silent update.
            if !inBackground { foregroundRefreshRequested = true }
            return await refreshTask.value
        }

        _ = loadCachedNews()
        if let lastAttempt, now().timeIntervalSince(lastAttempt) < 3 * 60 {
            return latestResult ?? availableNews()
        }
        if lastAttempt == nil, loadCachedNews() != nil,
            !dataLoader.isFileOlderThan(
                fileName: "news.json",
                date: calendar.date(byAdding: .minute, value: -3, to: now())
            )
        {
            return availableNews()
        }

        lastAttempt = now()
        foregroundRefreshRequested = !inBackground
        let task = Task { await performRefresh() }
        refreshTask = task
        let result = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        refreshTask = nil
        return result
    }

    private func performRefresh() async -> LoadingResult<[NewsItem]> {
        do {
            let apiNews = try await apiClient.fetchNews()
            try Task.checkCancellation()
            let items = uniqueNews(apiNews.map(convertAPINewsItemToNewsItem))
            let isBaseline = initializeBaseline(with: items)
            let stored = dataLoader.storeAPINewsToFile(news: apiNews, fileName: "news.json")
            source = .remote
            notice = stored ? nil : .storageFailed
            latestResult = .success(items)

            if isBaseline || foregroundRefreshRequested {
                remember(items.map(\.id))
            } else {
                // Record ineligible items before the first suspension, so a later language
                // change cannot replay them if the background task expires mid-batch.
                remember(
                    items.filter {
                        userSettings.readNews.contains($0.id) || !$0.isInLanguage(locale)
                    }.map(\.id))
                await notifyAboutNewItems(items)
            }
            return .success(items)
        } catch {
            if Task.isCancelled || error is CancellationError {
                return latestResult ?? availableNews()
            }
            AppLog.news.error(
                "News refresh failed: \(error.localizedDescription, privacy: .public)")
            let result = availableNews()
            if case .success = result {
                notice = source == .bundle ? .bundledAfterFailure : .refreshFailed
            }
            latestResult = result
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
            source = .bundle
            return .success(items)
        case .notFound, .unparsable:
            return .failure(.apiNotResponding)
        }
    }

    @discardableResult
    private func initializeBaseline(with items: [NewsItem]) -> Bool {
        guard !userSettings.newsBaselineInitialized else { return false }
        // Existing notification history is retained when upgrading older installations.
        let isFirstSnapshot = userSettings.oldNews.isEmpty
        userSettings.newsBaselineInitialized = true
        if isFirstSnapshot { remember(items.map(\.id)) }
        return isFirstSnapshot
    }

    private func remember(_ ids: [Int]) {
        var known = Set(userSettings.oldNews)
        let additions = ids.filter { known.insert($0).inserted }
        if !additions.isEmpty { userSettings.oldNews += additions }
    }

    private func uniqueNews(_ items: [NewsItem]) -> [NewsItem] {
        var ids = Set<Int>()
        return items.filter { ids.insert($0.id).inserted }
    }

    private func notifyAboutNewItems(_ items: [NewsItem]) async {
        for item in items where !userSettings.oldNews.contains(item.id) {
            guard !Task.isCancelled else { return }
            if foregroundRefreshRequested || userSettings.readNews.contains(item.id)
                || !item.isInLanguage(locale)
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
