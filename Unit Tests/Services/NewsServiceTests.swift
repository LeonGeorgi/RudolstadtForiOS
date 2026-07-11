import Testing
@testable import Rudolstadt

@Suite(.serialized)
@MainActor
struct NewsServiceTests {
    @Test
    func loadNewsUsesFreshCacheWithoutFetching() async {
        resetStoredNewsSettings()
        defer { resetStoredNewsSettings() }

        let cachedNews = [TestFixtures.newsItem(id: 7, languageCode: "en")]
        let cache = NewsCacheStub(loadResult: .loaded(cachedNews))
        let apiClient = NewsAPIStub()
        let service = NewsService(
            dataLoader: cache,
            apiClient: apiClient,
            userSettings: UserSettings(),
            notifier: NewsNotifierStub()
        )

        let result = await service.loadNews()

        guard case .success(let news) = result else {
            Issue.record("Expected cached news")
            return
        }
        #expect(news.map(\.id) == [7])
        #expect(apiClient.fetchCallCount == 0)
    }

    @Test
    func refreshNewsFetchesMissingCacheAndMarksItemsAsOld() async {
        resetStoredNewsSettings()
        defer { resetStoredNewsSettings() }

        let apiNews = [
            TestFixtures.apiNewsItem(id: 10, language: "en"),
            TestFixtures.apiNewsItem(id: 11, language: "de"),
        ]
        let cache = NewsCacheStub(loadResult: .notFound)
        let apiClient = NewsAPIStub(newsToReturn: apiNews)
        let settings = UserSettings()
        let notifier = NewsNotifierStub()
        let service = NewsService(
            dataLoader: cache,
            apiClient: apiClient,
            userSettings: settings,
            notifier: notifier
        )

        let result = await service.refreshNewsIfNecessary()

        guard case .success(let news) = result else {
            Issue.record("Expected fetched news")
            return
        }
        #expect(news.map(\.id) == [10, 11])
        #expect(apiClient.fetchCallCount == 1)
        #expect(cache.storedNewsIds == [10, 11])
        #expect(settings.oldNews == [10, 11])
        #expect(notifier.notifiedItemIds.isEmpty)
    }

    @Test
    func backgroundRefreshNotifiesOnlyNewItemsInCurrentLanguage() async {
        resetStoredNewsSettings()
        defer { resetStoredNewsSettings() }

        let apiNews = [
            TestFixtures.apiNewsItem(id: 1, language: "en"),
            TestFixtures.apiNewsItem(id: 2, language: "en"),
            TestFixtures.apiNewsItem(id: 3, language: "de"),
        ]
        let cache = NewsCacheStub(loadResult: .loaded([]))
        let apiClient = NewsAPIStub(newsToReturn: apiNews)
        let settings = UserSettings()
        settings.oldNews = [1]
        let notifier = NewsNotifierStub()
        let service = NewsService(
            dataLoader: cache,
            apiClient: apiClient,
            userSettings: settings,
            notifier: notifier
        )

        await service.refreshNewsInBackground()

        #expect(notifier.notifiedItemIds == [2])
        #expect(settings.oldNews == [1, 2])
    }

    private func resetStoredNewsSettings() {
        let settings = UserSettings()
        settings.oldNews = []
    }
}
