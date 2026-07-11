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

    private init() {}

    func requestOpeningNewsItem(id: Int) {
        requestedNewsItemID = id
    }

    func requestOpeningNewsItem(from response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo

        if let newsItemID = userInfo[NewsNotificationPayload.newsItemIDKey] as? Int {
            requestOpeningNewsItem(id: newsItemID)
        } else if let newsItemIDString = userInfo[NewsNotificationPayload.newsItemIDKey] as? String,
            let newsItemID = Int(newsItemIDString)
        {
            requestOpeningNewsItem(id: newsItemID)
        } else if let newsItemID = Int(response.notification.request.identifier) {
            requestOpeningNewsItem(id: newsItemID)
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
        let content = UNMutableNotificationContent()
        content.title = item.formattedShortDescription
        content.body = item.formattedLongDescription
        content.sound = .default
        content.userInfo = [
            NewsNotificationPayload.newsItemIDKey: item.id
        ]

        let request = UNNotificationRequest(
            identifier: String(item.id),
            content: content,
            trigger: nil
        )

        try await UNUserNotificationCenter.current().add(request)
    }
}

@MainActor
final class NewsService {
    private let dataLoader: NewsCaching
    private let apiClient: NewsFetching
    private let userSettings: UserSettings
    private let notifier: NewsNotifying

    init(
        dataLoader: NewsCaching,
        apiClient: NewsFetching,
        userSettings: UserSettings,
        notifier: NewsNotifying = UserNotificationNewsNotifier()
    ) {
        self.dataLoader = dataLoader
        self.apiClient = apiClient
        self.userSettings = userSettings
        self.notifier = notifier
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

    func loadNews() async -> LoadingResult<[NewsItem]> {
        let cachedNews = dataLoader.loadNewsFromFile()
        switch cachedNews {
        case .loaded(let news):
            AppLog.news.info("Loaded \(news.count) news items from cache")
            return .success(news)
        case .stale(let news):
            AppLog.news.info(
                "Cached news is stale with \(news.count) items; refreshing"
            )
            return await refreshNews()
        case .notFound:
            AppLog.news.info("No cached news found; refreshing")
            return await refreshNews()
        case .unparsable:
            AppLog.news.error("Cached news could not be parsed; refreshing from network")
            return await refreshNews()
        }
    }

    func refreshNewsIfNecessary() async -> LoadingResult<[NewsItem]> {
        guard shouldRefreshNews() else {
            return cachedNewsResult()
        }
        return await refreshNews()
    }

    func refreshNewsInBackground() async {
        _ = await refreshNews(
            markAllCurrentNewsAsSeen: false,
            sendNotifications: true
        )
    }

    private func refreshNews(
        markAllCurrentNewsAsSeen: Bool = true,
        sendNotifications: Bool = false
    ) async -> LoadingResult<[NewsItem]> {
        do {
            let apiNews = try await apiClient.fetchNews()
            let storedFile = dataLoader.storeAPINewsToFile(
                news: apiNews,
                fileName: "news.json"
            )
            if !storedFile {
                AppLog.news.error("Downloaded news but failed to cache it")
            }

            let newsItems = apiNews.map(convertAPINewsItemToNewsItem)
            let notifiedCount: Int

            if sendNotifications {
                notifiedCount = await notifyAboutNewItems(
                    apiNews: apiNews,
                    newsItems: newsItems
                )
            } else {
                notifiedCount = 0
            }
            if markAllCurrentNewsAsSeen {
                userSettings.oldNews = apiNews.map(\.id)
            }

            AppLog.news.info(
                "Refreshed news with \(newsItems.count) items and \(notifiedCount) notifications"
            )
            return .success(newsItems)
        } catch {
            AppLog.news.error(
                "News refresh failed: \(error.localizedDescription, privacy: .public)"
            )
            return cachedNewsResultOnFailure()
        }
    }

    private func shouldRefreshNews() -> Bool {
        switch dataLoader.loadNewsFromFile() {
        case .notFound, .unparsable:
            return true
        case .loaded, .stale:
            let someTimeAgo = Calendar.current.date(
                byAdding: .minute,
                value: -10,
                to: Date.now
            )
            return dataLoader.isFileOlderThan(
                fileName: "news.json",
                date: someTimeAgo
            )
        }
    }

    private func cachedNewsResult() -> LoadingResult<[NewsItem]> {
        switch dataLoader.loadNewsFromFile() {
        case .loaded(let news), .stale(let news):
            return .success(news)
        case .notFound, .unparsable:
            return bundledNewsBackupResult()
        }
    }

    private func cachedNewsResultOnFailure() -> LoadingResult<[NewsItem]> {
        switch dataLoader.loadNewsFromFile() {
        case .loaded(let news), .stale(let news):
            AppLog.news.info("Using cached news after refresh failure")
            return .success(news)
        case .notFound, .unparsable:
            return bundledNewsBackupResultOnFailure()
        }
    }

    private func bundledNewsBackupResult() -> LoadingResult<[NewsItem]> {
        switch dataLoader.loadBundledNewsBackup() {
        case .loaded(let news), .stale(let news):
            AppLog.news.info("Using bundled news backup with \(news.count) items")
            return .success(news)
        case .notFound, .unparsable:
            return .failure(.couldNotLoadFromFile)
        }
    }

    private func bundledNewsBackupResultOnFailure() -> LoadingResult<[NewsItem]> {
        switch dataLoader.loadBundledNewsBackup() {
        case .loaded(let news), .stale(let news):
            AppLog.news.info(
                "Using bundled news backup with \(news.count) items after refresh failure"
            )
            return .success(news)
        case .notFound, .unparsable:
            AppLog.news.error("News refresh failed and no cached news was available")
            return .failure(.apiNotResponding)
        }
    }

    private func notifyAboutNewItems(
        apiNews: [APINewsItem],
        newsItems: [NewsItem]
    ) async -> Int {
        let oldNewsIds = Set(userSettings.oldNews)
        let newNewsIds = Set(apiNews.map(\.id)).subtracting(oldNewsIds)
        var notifiedCount = 0

        for item in newsItems where newNewsIds.contains(item.id) && item.isInCurrentLanguage {
            do {
                try await notifier.notifyUser(of: item)
                userSettings.oldNews.append(item.id)
                notifiedCount += 1
            } catch {
                AppLog.news.error(
                    "Failed to notify user about news item \(item.id): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        return notifiedCount
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
