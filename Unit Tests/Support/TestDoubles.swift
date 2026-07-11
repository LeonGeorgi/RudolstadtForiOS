import Foundation
@testable import Rudolstadt

final class NewsAPIStub: NewsFetching {
    var newsToReturn: [APINewsItem]
    var fetchCallCount = 0

    init(newsToReturn: [APINewsItem] = []) {
        self.newsToReturn = newsToReturn
    }

    func fetchNews() async throws -> [APINewsItem] {
        fetchCallCount += 1
        return newsToReturn
    }
}

final class NewsCacheStub: NewsCaching {
    let loadResult: FileLoadingResult<[NewsItem]>
    var storedNewsIds: [Int] = []
    var isFileOlderThanReturnValue = true
    var requestedOlderThanDate: Date?

    init(loadResult: FileLoadingResult<[NewsItem]>) {
        self.loadResult = loadResult
    }

    func loadNewsFromFile() -> FileLoadingResult<[NewsItem]> {
        loadResult
    }

    func loadBundledNewsBackup() -> FileLoadingResult<[NewsItem]> {
        .notFound
    }

    func storeAPINewsToFile(news: [APINewsItem], fileName: String) -> Bool {
        storedNewsIds = news.map(\.id)
        return true
    }

    func isFileOlderThan(fileName: String, date: Date?) -> Bool {
        requestedOlderThanDate = date
        return isFileOlderThanReturnValue
    }
}

final class NewsNotifierStub: NewsNotifying {
    var notifiedItemIds: [Int] = []

    func notifyUser(of item: NewsItem) async throws {
        notifiedItemIds.append(item.id)
    }
}

final class RecommendationServiceStub: RecommendationProviding {
    let snapshot: RecommendationSnapshot

    init(snapshot: RecommendationSnapshot) {
        self.snapshot = snapshot
    }

    func buildSnapshot(
        data: FestivalData,
        savedEventIds: [Int],
        ratings: [String: Int],
        now: Date
    ) -> RecommendationSnapshot {
        snapshot
    }
}
