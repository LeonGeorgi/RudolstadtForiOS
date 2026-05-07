import BackgroundTasks
import Foundation
import UserNotifications

protocol NewsFetching {
    func fetchNews() async throws -> [APINewsItem]
}

protocol NewsCaching {
    func loadNewsFromFile() -> FileLoadingResult<[NewsItem]>
    func storeAPINewsToFile(news: [APINewsItem], fileName: String) -> Bool
    func isFileOlderThan(fileName: String, date: Date?) -> Bool
}

protocol NewsNotifying {
    func notifyUser(of item: NewsItem) async throws
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
        let cacheUrl = try! FileManager.default.url(
            for: .cachesDirectory,
            in: .allDomainsMask,
            appropriateFor: nil,
            create: false
        )
        self.init(
            dataLoader: DataLoader(cacheUrl: cacheUrl),
            apiClient: APIClient(),
            userSettings: userSettings
        )
    }

    func loadNews() async -> LoadingResult<[NewsItem]> {
        let cachedNews = dataLoader.loadNewsFromFile()
        switch cachedNews {
        case .loaded(let news):
            return .success(news)
        case .tooOld, .notFound, .unparsable:
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
                print("Could not store news to file")
            }

            let newsItems = apiNews.map(convertAPINewsItemToNewsItem)

            if sendNotifications {
                await notifyAboutNewItems(apiNews: apiNews, newsItems: newsItems)
            }
            if markAllCurrentNewsAsSeen {
                userSettings.oldNews = apiNews.map(\.id)
            }

            print("Updated news data")
            return .success(newsItems)
        } catch {
            print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
            print("!!! NEWS DOWNLOAD FAILED")
            print("!!! \(error.localizedDescription)")
            print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
            return cachedNewsResultOnFailure()
        }
    }

    private func shouldRefreshNews() -> Bool {
        switch dataLoader.loadNewsFromFile() {
        case .notFound, .unparsable:
            return true
        case .loaded, .tooOld:
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
        case .loaded(let news), .tooOld(let news):
            return .success(news)
        case .notFound, .unparsable:
            return .failure(.couldNotLoadFromFile)
        }
    }

    private func cachedNewsResultOnFailure() -> LoadingResult<[NewsItem]> {
        switch dataLoader.loadNewsFromFile() {
        case .loaded(let news), .tooOld(let news):
            return .success(news)
        case .notFound, .unparsable:
            return .failure(.apiNotResponding)
        }
    }

    private func notifyAboutNewItems(
        apiNews: [APINewsItem],
        newsItems: [NewsItem]
    ) async {
        let oldNewsIds = Set(userSettings.oldNews)
        let newNewsIds = Set(apiNews.map(\.id)).subtracting(oldNewsIds)

        for item in newsItems where newNewsIds.contains(item.id) && item.isInCurrentLanguage {
            do {
                try await notifier.notifyUser(of: item)
                userSettings.oldNews.append(item.id)
            } catch {
                print("Failed to notify user about news item \(item.id): \(error)")
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
            print("Scheduled news refresh task")
        } catch {
            print("Failed to schedule news refresh task: \(error)")
        }
    }

    /// Handle the task that the system launches.
    func handle() async {
        print("Handling news refresh task")
        NewsRefresher.scheduleNextBackgroundTask()
        await newsService.refreshNewsInBackground()
    }
}
