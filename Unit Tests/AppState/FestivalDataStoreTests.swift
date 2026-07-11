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

    private func makeStore(
        fetcher: FestivalDataFetcherStub,
        cache: FestivalDataCacheStub
    ) -> DataStore {
        let userSettings = TestFixtures.userSettings()
        let newsService = NewsService(
            dataLoader: NewsCacheStub(loadResult: .notFound),
            apiClient: NewsAPIStub(),
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
            loadInitialData: false
        )
    }
}
