import Testing
@testable import Rudolstadt

@MainActor
struct FestivalDataStoreTests {
    private enum StubError: Error {
        case unexpectedFetch
    }

    @Test
    func deferredInitializationPerformsNoFestivalDataAccess() {
        let cache = FestivalDataCacheStub()
        let fetcher = FestivalDataFetcherStub(data: TestFixtures.apiFestivalData())

        let store = makeStore(fetcher: fetcher, cache: cache)

        #expect(cache.loadCallCount == 0)
        #expect(fetcher.fetchCallCount == 0)
        if case .loading = store.festivalData {
            // Expected initial state.
        } else {
            Issue.record("Expected untouched loading state")
        }
    }

    @Test
    func freshInMemoryCacheAvoidsAPIFetch() async {
        let cachedData = TestFixtures.festivalData(events: [])
        let cache = FestivalDataCacheStub(loadResult: .loaded(cachedData))
        let fetcher = FestivalDataFetcherStub(error: StubError.unexpectedFetch)
        let store = makeStore(fetcher: fetcher, cache: cache)

        await store.loadOrRefreshFestivalData()

        #expect(cache.loadCallCount == 1)
        #expect(fetcher.fetchCallCount == 0)
        guard case .success(let festivalData) = store.festivalData else {
            Issue.record("Expected cached festival data")
            return
        }
        #expect(festivalData.events.isEmpty)
    }

    @Test
    func missingCacheFetchesAndStoresInjectedAPIData() async {
        let cache = FestivalDataCacheStub(loadResult: .notFound)
        let fetcher = FestivalDataFetcherStub(data: TestFixtures.apiFestivalData())
        let store = makeStore(fetcher: fetcher, cache: cache)

        await store.loadOrRefreshFestivalData()

        #expect(cache.loadCallCount == 1)
        #expect(cache.storeCallCount == 1)
        #expect(fetcher.fetchCallCount == 1)
        guard case .success(let festivalData) = store.festivalData else {
            Issue.record("Expected downloaded festival data")
            return
        }
        #expect(festivalData.artists.isEmpty)
        #expect(festivalData.events.isEmpty)
    }

    @Test
    func initializationPublishesCachedNewsImmediately() {
        let cachedNews = [TestFixtures.newsItem(id: 21, languageCode: "en")]
        let newsCache = NewsCacheStub(loadResult: .stale(cachedNews))
        let newsAPI = NewsAPIStub()
        let store = makeStore(
            fetcher: FestivalDataFetcherStub(data: TestFixtures.apiFestivalData()),
            cache: FestivalDataCacheStub(),
            newsCache: newsCache,
            newsAPI: newsAPI,
            loadInitialData: true
        )

        guard case .success(let news) = store.news else {
            Issue.record("Expected cached news during initialization")
            return
        }
        #expect(news.map(\.id) == [21])
        #expect(newsAPI.fetchCallCount == 0)
    }

    private func makeStore(
        fetcher: FestivalDataFetcherStub,
        cache: FestivalDataCacheStub,
        newsCache: NewsCacheStub = NewsCacheStub(loadResult: .notFound),
        newsAPI: NewsAPIStub = NewsAPIStub(),
        loadInitialData: Bool = false
    ) -> DataStore {
        let userSettings = TestFixtures.userSettings()
        let newsService = NewsService(
            dataLoader: newsCache,
            apiClient: newsAPI,
            userSettings: userSettings,
            notifier: NewsNotifierStub()
        )
        return DataStore(
            festivalProfileStore: TestFixtures.festivalProfileStore(),
            userSettings: userSettings,
            newsService: newsService,
            festivalDataFetcher: fetcher,
            festivalDataCache: cache,
            bundledNewsLoader: cache,
            loadInitialData: loadInitialData
        )
    }
}
