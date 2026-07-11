import Foundation
import Testing
@testable import Rudolstadt

@MainActor
struct NewsServiceTests {
    @Test
    func loadNewsUsesFreshCacheWithoutFetching() async {
        let cachedNews = [TestFixtures.newsItem(id: 7, languageCode: "en")]
        let cache = NewsCacheStub(loadResult: .loaded(cachedNews))
        let apiClient = NewsAPIStub()
        let service = NewsService(
            dataLoader: cache,
            apiClient: apiClient,
            userSettings: TestFixtures.userSettings(),
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
        let apiNews = [
            TestFixtures.apiNewsItem(id: 10, language: "en"),
            TestFixtures.apiNewsItem(id: 11, language: "de"),
        ]
        let cache = NewsCacheStub(loadResult: .notFound)
        let apiClient = NewsAPIStub(newsToReturn: apiNews)
        let settings = TestFixtures.userSettings()
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
    func refreshCheckUsesInjectedTimeAndCalendar() async {
        let cachedNews = [TestFixtures.newsItem(id: 12, languageCode: "en")]
        let cache = NewsCacheStub(loadResult: .loaded(cachedNews))
        cache.isFileOlderThanReturnValue = false
        let apiClient = NewsAPIStub()
        let now = TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        let service = NewsService(
            dataLoader: cache,
            apiClient: apiClient,
            userSettings: TestFixtures.userSettings(),
            notifier: NewsNotifierStub(),
            calendar: TestFixtures.festivalCalendar,
            locale: Locale(identifier: "en"),
            now: { now }
        )

        let result = await service.refreshNewsIfNecessary()

        guard case .success(let news) = result else {
            Issue.record("Expected cached news")
            return
        }
        #expect(news.map(\.id) == [12])
        #expect(
            cache.requestedOlderThanDate
                == now.addingTimeInterval(-10 * 60)
        )
        #expect(apiClient.fetchCallCount == 0)
    }

    @Test
    func backgroundRefreshNotifiesOnlyNewItemsInInjectedLanguage() async {
        let apiNews = [
            TestFixtures.apiNewsItem(id: 1, language: "en"),
            TestFixtures.apiNewsItem(id: 2, language: "en"),
            TestFixtures.apiNewsItem(id: 3, language: "de"),
        ]
        let cache = NewsCacheStub(loadResult: .loaded([]))
        let apiClient = NewsAPIStub(newsToReturn: apiNews)
        let settings = TestFixtures.userSettings()
        settings.oldNews = [1]
        let notifier = NewsNotifierStub()
        let service = NewsService(
            dataLoader: cache,
            apiClient: apiClient,
            userSettings: settings,
            notifier: notifier,
            locale: Locale(identifier: "en")
        )

        await service.refreshNewsInBackground()

        #expect(notifier.notifiedItemIds == [2])
        #expect(settings.oldNews == [1, 2])
    }
}
