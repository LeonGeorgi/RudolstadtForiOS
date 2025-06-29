import BackgroundTasks
import Foundation
import UserNotifications

final class NewsRefresher {

    let dataLoader: DataLoader
    let apiClient: APIClient

    let cacheUrl: URL

    init() {
        cacheUrl = try! FileManager.default.url(
            for: .cachesDirectory,
            in: .allDomainsMask,
            appropriateFor: nil,
            create: false
        )
        dataLoader = DataLoader(cacheUrl: cacheUrl)
        apiClient = APIClient()
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

        do {
            let apiNews = try await apiClient.fetchNews()
            print("Fetched \(apiNews.count) news items from API")
            let newsStored = dataLoader.storeAPINewsToFile(
                news: apiNews,
                fileName: "news.json"
            )
            if !newsStored {
                print("Failed to store news to file")

            }

            let oldNewsIds = UserSettings().oldNews
            let newNews = apiNews.filter { !oldNewsIds.contains($0.id) }
            print("Found \(newNews.count) new news items")

            let convertedNews = newNews.map(convertAPINewsItemToNewsItem)

            for item in convertedNews.filter({
                newsItem
                in newsItem.isInCurrentLanguage
            }) {
                try await notifyUser(of: item)
                UserSettings().oldNews.append(item.id)
            }

        } catch {
            print("Error fetching news: \(error)")
        }
    }

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
