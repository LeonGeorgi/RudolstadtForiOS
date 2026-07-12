import Foundation
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
    func staleCacheRemainsVisibleWhenRefreshFails() async {
        let cachedData = TestFixtures.festivalData(events: [fixtureEvent(id: 41)])
        let cache = FestivalDataCacheStub(loadResult: .stale(cachedData))
        let store = makeStore(
            fetcher: FestivalDataFetcherStub(error: URLError(.notConnectedToInternet)),
            cache: cache
        )

        await store.loadOrRefreshFestivalData()

        #expect(successfulEventIDs(in: store) == [41])
        #expect(store.isUsingBundledFestivalDataBackup == false)
        guard let fallbackStatus = store.festivalDataFallbackStatus else {
            Issue.record("Expected stale-cache fallback status")
            return
        }
        if case .staleCache = fallbackStatus.source {} else {
            Issue.record("Expected stale-cache fallback source")
        }
        if case .connection = fallbackStatus.failure.owner {} else {
            Issue.record("Expected connection failure owner")
        }
        #expect(cache.bundledFestivalLoadCallCount == 0)
    }

    @Test
    func successfulRefreshReplacesStaleCache() async {
        let cachedData = TestFixtures.festivalData(events: [fixtureEvent(id: 44)])
        let cache = FestivalDataCacheStub(loadResult: .stale(cachedData))
        let store = makeStore(
            fetcher: FestivalDataFetcherStub(
                data: TestFixtures.apiFestivalData(artistID: 52)
            ),
            cache: cache
        )

        await store.loadOrRefreshFestivalData()

        #expect(successfulArtistIDs(in: store) == [52])
        #expect(successfulEventIDs(in: store) == [])
        #expect(cache.storeCallCount == 1)
        #expect(store.festivalDataFallbackStatus == nil)
    }

    @Test
    func successfulRefreshRecoversFromUnparsableCache() async {
        let cache = FestivalDataCacheStub(loadResult: .unparsable)
        let store = makeStore(
            fetcher: FestivalDataFetcherStub(
                data: TestFixtures.apiFestivalData(artistID: 53)
            ),
            cache: cache
        )

        await store.loadOrRefreshFestivalData()

        #expect(successfulArtistIDs(in: store) == [53])
        #expect(cache.storeCallCount == 1)
        #expect(cache.bundledFestivalLoadCallCount == 0)
    }

    @Test
    func missingCacheUsesBundledBackupWhenRefreshFails() async {
        let backup = TestFixtures.festivalData(events: [fixtureEvent(id: 42)])
        let cache = FestivalDataCacheStub(
            loadResult: .notFound,
            bundledFestivalResult: .loaded(backup)
        )
        let store = makeStore(
            fetcher: FestivalDataFetcherStub(error: StubError.unexpectedFetch),
            cache: cache
        )

        await store.loadOrRefreshFestivalData()

        #expect(successfulEventIDs(in: store) == [42])
        #expect(store.isUsingBundledFestivalDataBackup)
        guard let fallbackStatus = store.festivalDataFallbackStatus else {
            Issue.record("Expected bundled-backup fallback status")
            return
        }
        if case .bundledBackup = fallbackStatus.source {} else {
            Issue.record("Expected bundled-backup fallback source")
        }
        #expect(cache.bundledFestivalLoadCallCount == 1)
    }

    @Test
    func unavailableCacheAndBackupPublishFailure() async {
        for cacheResult in [
            FileLoadingResult<FestivalData>.notFound,
            .unparsable,
        ] {
            let cache = FestivalDataCacheStub(loadResult: cacheResult)
            let store = makeStore(
                fetcher: FestivalDataFetcherStub(error: StubError.unexpectedFetch),
                cache: cache
            )

            await store.loadOrRefreshFestivalData()

            guard case .failure(.apiNotResponding) = store.festivalData else {
                Issue.record("Expected API failure without a usable fallback")
                continue
            }
            #expect(cache.bundledFestivalLoadCallCount == 1)
        }
    }

    @Test
    func failedRefreshPreservesAlreadyVisibleData() async {
        let visibleData = TestFixtures.festivalData(events: [fixtureEvent(id: 43)])
        let cache = FestivalDataCacheStub(loadResult: .notFound)
        let store = makeStore(
            fetcher: FestivalDataFetcherStub(error: StubError.unexpectedFetch),
            cache: cache
        )
        store.festivalData = .success(visibleData)

        await store.loadOrRefreshFestivalData()

        #expect(successfulEventIDs(in: store) == [43])
        #expect(cache.bundledFestivalLoadCallCount == 0)
    }

    @Test
    func cacheWriteFailureDoesNotDiscardDownloadedData() async {
        let cache = FestivalDataCacheStub(loadResult: .notFound, storeResult: false)
        let store = makeStore(
            fetcher: FestivalDataFetcherStub(data: TestFixtures.apiFestivalData(artistID: 51)),
            cache: cache
        )

        await store.loadOrRefreshFestivalData()

        #expect(successfulArtistIDs(in: store) == [51])
        #expect(cache.storeCallCount == 1)
        #expect(store.isUsingBundledFestivalDataBackup == false)
        #expect(store.festivalDataFallbackStatus == nil)
    }

    @Test
    func refreshPublishesCacheModificationDate() async {
        let modificationDate = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = FestivalDataCacheStub(
            loadResult: .loaded(TestFixtures.festivalData(events: [])),
            modificationDate: modificationDate
        )
        let store = makeStore(
            fetcher: FestivalDataFetcherStub(error: StubError.unexpectedFetch),
            cache: cache
        )

        await store.loadOrRefreshFestivalData()

        #expect(store.festivalDataLastDownloadDate == modificationDate)
    }

    @Test
    func olderConcurrentRefreshCannotOverwriteNewerResult() async {
        let fetcher = ControlledFestivalDataFetcher()
        let cache = FestivalDataCacheStub(loadResult: .notFound)
        let store = makeStore(fetcher: fetcher, cache: cache)

        let firstRefresh = Task { await store.loadOrRefreshFestivalData() }
        await waitForFetchCount(1, fetcher: fetcher)
        let secondRefresh = Task { await store.loadOrRefreshFestivalData() }
        await waitForFetchCount(2, fetcher: fetcher)

        await fetcher.resumeFetch(at: 1, with: TestFixtures.apiFestivalData(artistID: 62))
        await secondRefresh.value
        await fetcher.resumeFetch(at: 0, with: TestFixtures.apiFestivalData(artistID: 61))
        await firstRefresh.value

        #expect(successfulArtistIDs(in: store) == [62])
        #expect(cache.storeCallCount == 1)
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
        fetcher: any FestivalDataFetching,
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

    private func fixtureEvent(id: Int) -> Event {
        TestFixtures.event(
            id: id,
            dayInJuly: 3,
            timeAsString: "12:00",
            stage: TestFixtures.stage(id: id),
            artist: TestFixtures.artist(id: id)
        )
    }

    private func successfulEventIDs(in store: DataStore) -> [Int]? {
        guard case .success(let data) = store.festivalData else {
            return nil
        }
        return data.events.map(\.id)
    }

    private func successfulArtistIDs(in store: DataStore) -> [Int]? {
        guard case .success(let data) = store.festivalData else {
            return nil
        }
        return data.artists.map(\.id)
    }

    private func waitForFetchCount(
        _ expectedCount: Int,
        fetcher: ControlledFestivalDataFetcher
    ) async {
        while await fetcher.fetchCallCount < expectedCount {
            await Task.yield()
        }
    }
}
