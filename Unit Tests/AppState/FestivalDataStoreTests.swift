import Combine
import Foundation
import PDFKit
import Testing
@testable import Rudolstadt

@MainActor
struct FestivalDataStoreTests {
    @Test
    func ludwigsburgLoadsJuneProgramWithPublishedDurationsAndIndependentMetadata() async throws {
        let provider = LudwigsburgFestivalDataProvider()
        let data = try await provider.refresh()
        #expect(data.artists.count == 37)
        #expect(data.events.count == 219)
        #expect(data.stages.count == 11)
        #expect(data.omittedRecordCount == 1)
        #expect(data.festivalYear == 2026)
        #expect(data.festivalMonth == 6)
        #expect(data.stages.allSatisfy { $0.hasLocation && $0.locationIsApproximate })
        #expect(data.events.allSatisfy { !$0.hasCompleteMetadata })
        let plan = try #require(data.sitePlan)
        let planURL = try #require(plan.resourceURL())
        let document = try #require(PDFDocument(url: planURL))
        #expect(document.pageCount == 1)
        #expect(plan.locations.count == 49)
        #expect(plan.locations.filter { $0.category != .stage }.count == 38)
        #expect(plan.locations.compactMap(\.coordinate).count == 46)
        #expect(plan.locations.compactMap(\.coordinate).allSatisfy { $0.isValid && $0.isApproximate })
        #expect(plan.locations.compactMap(\.stageID).count == data.stages.count)
        #expect(plan.locations.compactMap(\.point).allSatisfy { $0.isValid })
        #expect(plan.locations.first { $0.id == "stage-a" }?.stageID == 9)
        #expect(plan.location(forStageID: 9)?.reference == "A")
        #expect(data.stages.map(\.displayCode) == ["A", "B", "C", "D", "E", "F", "G", "H", "I", "K", "M"])
        #expect(data.stages.allSatisfy { stage in
            stage.stageNumber == nil && stage.displayCode == plan.location(forStageID: stage.id)?.reference
        })
        #expect(data.events.allSatisfy { event in
            event.stage.displayCode == plan.location(forStageID: event.stage.id)?.reference
        })
        #expect(plan.locations.filter { $0.category == .toilets }.count == 6)
        #expect(plan.locations.first { $0.id == "parking-marstall" }?.point == nil)
        #expect(plan.locations.first { $0.id == "parking-marstall" }?.coordinate != nil)
        #expect(plan.locations.first { $0.id == "parking-rathaus" }?.coordinate == nil)
        #expect(plan.locations.first { $0.id == "activity-face-painting" }?.point == nil)
        #expect(plan.locations.first { $0.id == "activity-photo" }?.point == nil)
        #expect(plan.locations.first { $0.id == "food-parkcafe" }?
            .matches("Parkcafé", locale: Locale(identifier: "de")) == true)
        #expect(plan.locations.first { $0.id == "activity-photo" }?
            .localizedName(locale: Locale(identifier: "en")) == "Photo booth")
        #expect(data.artistSimilarities == nil)
        #expect(provider.loadBrowseTaxonomy().isEmpty)
        #expect(provider.loadArtistLinks().isEmpty)
        let calendar = FestivalDateUtilities.festivalCalendar
        #expect(Set(data.events.map(\.festivalDay)) == [20, 21])
        #expect(data.events.allSatisfy {
            guard let date = $0.startDate else { return false }
            return calendar.component(.month, from: date) == 6
                && $0.durationMinutes.map { (20...30).contains($0) } == true
        })
        let firstArtist = try #require(data.artists.first { $0.id == 1 })
        #expect(firstArtist.countryCodes == ["UKR"])
        #expect(firstArtist.fullImageUrl?.host == "strassenmusikfestival.de")
        #expect(firstArtist.descriptionGerman?.contains("ukrainische") == true)
        let openingSet = try #require(data.events.first { $0.artist.id == 1 && $0.timeAsString == "14:20" })
        let durations = RecommendationService().estimateEventDurations(events: [openingSet])
        #expect(durations[openingSet.id] == 20)
        #expect(openingSet.shortWeekDay(calendar: calendar, locale: Locale(identifier: "en")) == "Sat")
        #expect(FestivalDateUtilities.shortWeekDay(day: 20, year: 2026, month: data.festivalMonth,
                                                 locale: Locale(identifier: "en")) == "Sat")
        #expect(FestivalDateUtilities.getCurrentFestivalDay(
            eventDays: [20, 21], now: try #require(openingSet.startDate),
            festivalYear: 2026, festivalMonth: 6
        ) == 20)
    }

    @Test(arguments: ["festivalID", "schemaVersion", "duplicateArtist", "missingStage", "duration",
                      "planPoint", "planStage", "duplicatePlace", "coordinate"])
    func ludwigsburgRejectsInvalidSnapshots(field: String) async throws {
        let bundleURL = try #require(Bundle.main.url(forResource: "ludwigsburg_2026", withExtension: "json"))
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: bundleURL)) as? [String: Any])
        switch field {
        case "festivalID": json[field] = "rudolstadt-2026"
        case "schemaVersion": json[field] = 999
        case "duplicateArtist":
            var artists = try #require(json["artists"] as? [[String: Any]])
            artists.append(try #require(artists.first))
            json["artists"] = artists
        case "planPoint", "planStage", "duplicatePlace", "coordinate":
            var plan = try #require(json["sitePlan"] as? [String: Any])
            var locations = try #require(plan["locations"] as? [[String: Any]])
            switch field {
            case "planPoint": locations[0]["point"] = ["x": 2.0, "y": 0.5]
            case "planStage": locations[0]["stageID"] = 999
            case "coordinate": locations[0]["coordinate"] = ["latitude": 200, "longitude": 9,
                                                              "isApproximate": true]
            default: locations.append(try #require(locations.first))
            }
            plan["locations"] = locations
            json["sitePlan"] = plan
        default:
            var events = try #require(json["events"] as? [[String: Any]])
            events[0][field == "duration" ? "durationMinutes" : "stage"] = -1
            json["events"] = events
        }
        #expect(throws: (any Error).self) {
            try LudwigsburgFestivalDataProvider.decode(JSONSerialization.data(withJSONObject: json))
        }
    }

    @Test
    func ludwigsburgPersonalDataPersistsSeparatelyFromRudolstadtAndArchives() async throws {
        let suiteName = "RudolstadtTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set([77], forKey: "2026/savedEvents")
        defaults.set(["1": 3], forKey: "2026/ratings")
        defaults.set(["1": "Rudolstadt note"], forKey: "2026/artistNotes")
        let settings = UserSettings(userDefaults: defaults)
        let current = FestivalProfileStore(userDefaults: defaults, cloudKitEnabled: false)
        let services = AppServices(userSettings: settings, festivalProfileStore: current,
                                   festivalAdapter: FestivalRegistry.rudolstadt(year: 2026, source: FestivalDataProviderStub(), archive: false, includesSupplementaryInformation: false))
        let before = defaults.persistentDomain(forName: suiteName) as NSDictionary?
        let testStore = services.dataStore(for: .ludwigsburg2026)
        await testStore.loadFestivalContentForAppLaunch()
        #expect(before == defaults.persistentDomain(forName: suiteName) as NSDictionary?)
        let profile = testStore.festivalProfileStore
        #expect(!profile.isReadOnly)
        #expect(profile.ratings.isEmpty)
        #expect(profile.savedEvents.isEmpty)
        #expect(profile.artistNotes.isEmpty)
        #expect(profile.friendProfilesStore.profiles.isEmpty)
        #expect(testStore.festivalDataProvenance?.source == .bundledExperiment)
        guard case .success(let data) = testStore.festivalData else {
            Issue.record("Expected the bundled Ludwigsburg program")
            return
        }
        let event = try #require(data.events.first)
        profile.setArtistRating(for: event.artist, rating: 1)
        profile.setArtistNote(for: event.artist, note: "Local Ludwigsburg note")
        profile.toggleSavedEvent(event)
        await profile.flushPendingPersistence()
        let reopened = DataStore(userSettings: settings, edition: .ludwigsburg2026, loadInitialData: false)
        #expect(reopened.festivalProfileStore.rating(for: event.artist.id) == 1)
        #expect(reopened.festivalProfileStore.savedEvents == [event.id])
        #expect(reopened.festivalProfileStore.noteText(for: event.artist) == "Local Ludwigsburg note")
        #expect(current.rating(for: 1) == 3)
        #expect(current.savedEvents == [77])
        #expect(current.artistNotes["1"] == "Rudolstadt note")
        #expect(services.dataStore(for: .current).festivalProfileStore === current)
        #expect(services.dataStore(for: .ludwigsburg2026) === testStore)
    }

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
        #expect(store.festivalDataProvenance?.source == .remote)
        #expect(store.festivalDataProvenance?.dataUpdatedAt != nil)
    }

    @Test
    func returningFromArchiveRechecksTheCurrentProgram() async {
        let initial = TestFixtures.festivalData(events: [fixtureEvent(id: 906)])
        let latest = TestFixtures.festivalData(events: [fixtureEvent(id: 907)])
        let cache = FestivalDataCacheStub(loadResult: .loaded(initial))
        let store = makeStore(
            fetcher: FestivalDataFetcherStub(error: StubError.unexpectedFetch), cache: cache
        )
        let firstAppearance = Date(timeIntervalSince1970: 1_700_000_000)
        await store.loadFestivalContentForAppLaunch(now: firstAppearance)
        #expect(successfulEventIDs(in: store) == [906])
        cache.setLoadResult(.loaded(latest))

        await store.loadFestivalContentForAppLaunch(now: firstAppearance.addingTimeInterval(14_400))

        #expect(successfulEventIDs(in: store) == [907])
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
        #expect(store.festivalDataProvenance?.source == .staleCache)
        #expect(store.festivalDataProvenance?.refreshCheckedAt != nil)
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
        #expect(store.festivalDataProvenance?.source == .bundledBackup)
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
        #expect(store.festivalDataProvenance == FestivalDataProvenance(
            source: .cache,
            dataUpdatedAt: modificationDate,
            refreshCheckedAt: nil
        ))
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

        guard case .success(let news) = store.newsStore.news else {
            Issue.record("Expected cached news during initialization")
            return
        }
        #expect(news.map(\.id) == [21])
        #expect(newsAPI.fetchCallCount == 0)
    }

    @Test
    func refreshingNewsDoesNotPublishFestivalOrRecommendationChanges() async {
        let store = makeStore(
            fetcher: FestivalDataFetcherStub(data: TestFixtures.apiFestivalData()),
            cache: FestivalDataCacheStub(),
            newsAPI: NewsAPIStub(newsToReturn: [TestFixtures.apiNewsItem(id: 52, language: "en")])
        )
        var festivalChanges = 0
        var recommendationChanges = 0
        var publishedNewsIDs: [[Int]] = []
        let festivalObservation = store.objectWillChange.sink { festivalChanges += 1 }
        let recommendationObservation = store.recommendationStore.objectWillChange
            .sink { recommendationChanges += 1 }
        let newsObservation = store.newsStore.$news.dropFirst().sink { state in
            if case .success(let items) = state {
                publishedNewsIDs.append(items.map(\.id))
            }
        }
        defer {
            festivalObservation.cancel()
            recommendationObservation.cancel()
            newsObservation.cancel()
        }

        await store.newsStore.refreshNewsIfNecessary()

        #expect(publishedNewsIDs == [[52]])
        #expect(festivalChanges == 0)
        #expect(recommendationChanges == 0)
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
            festivalAdapter: FestivalRegistry.rudolstadt(year: 2026, source: RudolstadtFestivalDataProvider(
                fetcher: fetcher, cache: cache, extraData: .empty()
            ), archive: false, includesSupplementaryInformation: false),
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

extension FestivalDataStoreTests {
    @Test
    func replacementProviderSuppliesCompleteCachedProgramAndSupplementaryData() async {
        var data = TestFixtures.festivalData(events: [fixtureEvent(id: 901)])
        data.omittedRecordCount = 2
        data.artistSimilarities = ArtistSimilarityCatalog(
            festivalYear: DataStore.year, similarArtistIDsByArtistID: [901: [902]]
        )
        data.walkingDistanceMatrix = StageWalkingDistanceMatrix(
            distancesByStageID: [901: [902: 500]]
        )
        let taxonomy = [BrowseTaxonomyEntry(id: "custom", labelDE: "Eigene", labelEN: "Custom")]
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let links = ArtistLinks(
            spotifyURL: "https://example.com/custom-artist",
            appleMusicPreviewSelection: .disabled
        )
        let provider = FestivalDataProviderStub(
            cachedData: .loaded(data), cacheModificationDate: date, isCacheStale: false,
            taxonomy: taxonomy, links: [data.artists[0].name: links]
        )
        let store = makeStore(provider: provider, loadInitialData: true)

        await store.loadFestivalContentForAppLaunch()

        guard case .success(let loaded) = store.festivalData else {
            Issue.record("Expected the replacement provider's program")
            return
        }
        #expect(loaded.artists.map(\.id) == data.artists.map(\.id))
        #expect(loaded.areas.map(\.id) == data.areas.map(\.id))
        #expect(loaded.stages.map(\.id) == data.stages.map(\.id))
        #expect(loaded.events.map(\.id) == [901])
        #expect(loaded.omittedRecordCount == 2)
        #expect(loaded.artistSimilarities?.similarArtistIDsByArtistID == [901: [902]])
        #expect(store.features.distances.isSupported)
        #expect(loaded.artists[0].thumbImageUrlString == data.artists[0].thumbImageUrlString)
        #expect(store.browseTaxonomy == taxonomy)
        #expect(store.localizedBrowseGenreLabel(for: "custom") == taxonomy[0].localizedLabel)
        #expect(store.features.artistDetails.value?.details(for: data.artists[0].id)?.links.contains {
            $0.id == "spotify" && $0.destination.absoluteString == links.spotifyURL
        } == true)
        #expect(store.artistLinks?[data.artists[0].name]?.spotifyURL == links.spotifyURL)
        #expect(store.festivalDataProvenance?.source == .cache)
        #expect(store.festivalDataLastDownloadDate == date)
        #expect(!store.isFestivalDataCacheStale)
    }

    @Test
    func replacementProviderRefreshNeedsNoRudolstadtWireFormat() async {
        let data = TestFixtures.festivalData(events: [fixtureEvent(id: 902)])
        let provider = FestivalDataProviderStub(refreshResult: .success(data))
        let store = makeStore(provider: provider)

        await store.loadOrRefreshFestivalData()

        #expect(successfulArtistIDs(in: store) == [902])
        #expect(successfulEventIDs(in: store) == [902])
        #expect(store.browseTaxonomy.isEmpty)
        if case .success(let loaded) = store.festivalData {
            #expect(loaded.artistSimilarities == nil)
            #expect(loaded.walkingDistanceMatrix == .empty)
        }
        #expect(store.festivalDataProvenance?.source == .remote)
    }

    @Test
    func replacementProviderUsesOnlyItsOwnBackup() async {
        let backup = TestFixtures.festivalData(events: [fixtureEvent(id: 903)])
        let store = makeStore(provider: FestivalDataProviderStub(bundledData: .loaded(backup)))

        await store.loadOrRefreshFestivalData()

        #expect(successfulEventIDs(in: store) == [903])
        #expect(store.festivalDataProvenance?.source == .bundledBackup)
    }

    @Test
    func replacementProviderWithoutBackupDoesNotLoadRudolstadtBackup() async {
        let store = makeStore(provider: FestivalDataProviderStub())

        await store.loadOrRefreshFestivalData()

        guard case .failure(.apiNotResponding) = store.festivalData else {
            Issue.record("Expected failure rather than unrelated bundled festival data")
            return
        }
        #expect(store.festivalDataProvenance == nil)
    }

    @Test
    func cancelledRefreshDoesNotCacheOrReplaceVisibleData() async {
        let fetcher = ControlledFestivalDataFetcher()
        let cache = FestivalDataCacheStub()
        let store = makeStore(fetcher: fetcher, cache: cache)
        store.festivalData = .success(TestFixtures.festivalData(events: [fixtureEvent(id: 904)]))
        let refresh = Task { await store.loadOrRefreshFestivalData() }
        await waitForFetchCount(1, fetcher: fetcher)

        refresh.cancel()
        await fetcher.resumeFetch(at: 0, with: TestFixtures.apiFestivalData(artistID: 905))
        await refresh.value

        #expect(successfulEventIDs(in: store) == [904])
        #expect(cache.storeCallCount == 0)
        #expect(cache.bundledFestivalLoadCallCount == 0)
        #expect(store.festivalDataFallbackStatus == nil)
    }

    @Test
    func rudolstadtAdapterPreservesServerFailureClassification() async {
        let provider = RudolstadtFestivalDataProvider(
            fetcher: FestivalDataFetcherStub(
                error: APIClientError.httpStatus(endpoint: .events, statusCode: 503, bodyPreview: "Unavailable")
            ), cache: FestivalDataCacheStub(), extraData: .empty()
        )
        let store = makeStore(provider: provider)

        await store.loadOrRefreshFestivalData()

        guard case .failure(.festivalServerError) = store.festivalData else {
            Issue.record("Expected provider-independent server failure")
            return
        }
    }

    private func makeStore(
        provider: any FestivalDataProviding,
        loadInitialData: Bool = false
    ) -> DataStore {
        let settings = TestFixtures.userSettings()
        return DataStore(
            festivalProfileStore: TestFixtures.festivalProfileStore(),
            userSettings: settings,
            newsService: NewsService(
                dataLoader: NewsCacheStub(loadResult: .notFound),
                apiClient: NewsAPIStub(), userSettings: settings, notifier: NewsNotifierStub()
            ),
            festivalAdapter: FestivalRegistry.rudolstadt(year: 2026, source: provider, archive: false, includesSupplementaryInformation: false),
            bundledNewsLoader: FestivalDataCacheStub(),
            loadInitialData: loadInitialData
        )
    }
}

@MainActor
struct FestivalArchiveTests {
    @Test(arguments: [2019, 2022, 2023, 2024, 2025])
    func everyAvailableArchiveLoadsACompleteProgram(year: Int) async throws {
        let expected = [2019: (158, 290, 48), 2022: (142, 259, 46),
                        2023: (140, 282, 43), 2024: (151, 304, 45), 2025: (154, 294, 35)]
        let counts = try #require(expected[year])
        let data = try await RudolstadtArchiveDataProvider(year: year).refresh()
        #expect(data.festivalYear == year)
        #expect(data.artists.count == counts.0)
        #expect(data.events.count == counts.1)
        #expect(data.stages.count == counts.2)
        #expect(data.events.allSatisfy { event in
            guard let start = event.startDate else { return false }
            return TestFixtures.festivalCalendar.component(.year, from: start) == year
                && data.artists.contains { $0.id == event.artist.id }
                && data.stages.contains { $0.id == event.stage.id }
        })
        #expect(FestivalEdition(year: year)?.isArchive == true)
        #expect(FestivalEdition(year: 2020) == nil)
        #expect(FestivalEdition(year: 2021) == nil)
        if year == 2025 {
            let artist = try #require(data.artists.first { $0.id == 4 })
            #expect(artist.instagram == "https://www.instagram.com/bigbandofboom/")
            #expect(artist.thumbImageUrl?.path.hasPrefix("/assets/images/3/") == true)
            #expect(artist.fullImageUrl?.lastPathComponent.contains("©") == true)
            #expect(artist.countryCodes == ["GBR"])
            #expect(data.artists.contains { $0.artistType == .street })
        }
    }

    @Test
    func switchingBetweenArchivesUsesEachYearsPersonalDataAndPreservesCurrent() async throws {
        let defaults = TestFixtures.isolatedUserDefaults()
        let years = FestivalEdition.availableEditions.filter(\.isArchive)
        for edition in years {
            defaults.set([edition.year], forKey: "\(edition.year)/savedEvents")
            defaults.set(["4": edition.year % 3 + 1], forKey: "\(edition.year)/ratings")
            defaults.set(["4": "Note \(edition.year)"], forKey: "\(edition.year)/artistNotes")
        }
        let settings = UserSettings(userDefaults: defaults)
        let profile = FestivalProfileStore(userDefaults: defaults, cloudKitEnabled: false)
        let currentData = TestFixtures.festivalData(events: [])
        let services = AppServices(
            userSettings: settings, festivalProfileStore: profile,
            festivalAdapter: FestivalRegistry.rudolstadt(year: 2026, source: FestivalDataProviderStub(
                cachedData: .loaded(currentData), refreshResult: .success(currentData)
            ), archive: false, includesSupplementaryInformation: false))
        for edition in years {
            let archive = services.dataStore(for: edition)
            await archive.loadFestivalContentForAppLaunch()
            guard case .success(let data) = archive.festivalData else {
                Issue.record("Archive failed: \(edition.year)")
                return
            }
            #expect(data.festivalYear == edition.year)
            #expect(archive.festivalProfileStore.savedEvents == [edition.year])
            #expect(archive.festivalProfileStore.rating(for: 4) == edition.year % 3 + 1)
            #expect(archive.festivalProfileStore.artistNotes["4"] == "Note \(edition.year)")
            #expect(archive.festivalProfileStore.isReadOnly)
            #expect(services.dataStore(for: edition) === archive)
        }
        #expect(services.dataStore(for: .current).festivalProfileStore === profile)
        #expect(profile.savedEvents.isEmpty)
        #expect(profile.ratings.isEmpty)
    }

    @Test(arguments: ["yearCache", "legacyCache", "bothCaches", "wrongYear", "corruptCache"])
    func archiveReadsExistingCachesWithoutMigrationOrWrites(source: String) async throws {
        let defaults = TestFixtures.isolatedUserDefaults()
        defaults.set([42], forKey: "2024/savedEvents")
        defaults.set(["7": "Old note"], forKey: "2024/artistNotes")
        defaults.set(["8": -1], forKey: "2024/ratings")
        defaults.set(["8": "zzz"], forKey: "2024/artistIcons")
        let persistence = UserDefaultsFestivalProfilePersistence(userDefaults: defaults, festivalYear: 2024)
        var owner = persistence.loadLegacyOwnerProfile()
        owner.savedEventIDs = [99]
        if source == "wrongYear" { owner.festivalYear = 2026 }
        let cache = FestivalProfileCache(currentProfile: owner, sharedProfiles: [], migrationVersion: 1,
                                        lastSuccessfulRefreshDate: nil, privateStateSerializationData: nil,
                                        sharedStateSerializationData: nil)
        let encoded = try JSONEncoder().encode(cache)
        let yearKey = FestivalProfileStore.Constants.cacheKey(for: 2024)
        let legacyKey = FestivalProfileStore.Constants.legacyCacheKey
        defaults.set(source == "corruptCache" ? Data("broken".utf8) : encoded,
                     forKey: source == "legacyCache" ? legacyKey : yearKey)
        if source == "bothCaches" {
            var older = cache
            older.currentProfile.savedEventIDs = [123]
            defaults.set(try JSONEncoder().encode(older), forKey: legacyKey)
        }
        let before = defaults.dictionaryRepresentation() as NSDictionary
        let archive = FestivalProfileStore(userDefaults: defaults, readOnlyFestivalYear: 2024, cloudKitEnabled: true)
        #expect(archive.savedEvents == (["wrongYear", "corruptCache"].contains(source) ? [42] : [99]))
        #expect(archive.rating(for: 8) == -1)
        #expect(archive.iconName(forArtistID: 8) == "zzz")
        #expect(archive.artistNotes["7"] == "Old note")
        archive.setArtistNote(forArtistID: 7, note: "Changed")
        await archive.refreshFromCloud()
        await archive.flushPendingPersistence()
        #expect(archive.artistNotes["7"] == "Old note")
        #expect(before == defaults.dictionaryRepresentation() as NSDictionary)
    }

    @Test
    func bundled2024ArchivePreservesDatesTypesReferencesAndImages() async throws {
        let provider = RudolstadtArchiveDataProvider(year: 2024)
        let data = try await provider.refresh()

        #expect(data.festivalYear == 2024)
        #expect(data.artists.count == 151)
        #expect(data.events.count == 304)
        #expect(data.stages.count == 45)
        #expect(data.areas.count == 9)
        #expect(data.omittedRecordCount == 0)
        #expect(data.artistSimilarities == nil)
        #expect(data.walkingDistanceMatrix == .empty)
        #expect(data.artists.contains { $0.artistType == .street })
        #expect(data.events.contains { $0.tags.count > 1 })
        let first = try #require(data.events.first)
        let date = try #require(first.startDate)
        #expect(TestFixtures.festivalCalendar.component(.year, from: date) == 2024)
        #expect(first.shortWeekDay(calendar: TestFixtures.festivalCalendar, locale: Locale(identifier: "en")) == "Thu")
        #expect(data.events.allSatisfy { event in
            data.artists.contains { $0.id == event.artist.id }
                && data.stages.contains { $0.id == event.stage.id }
        })
        let artist = try #require(data.artists.first { $0.id == 1079 })
        #expect(artist.thumbImageUrl?.path.contains("/data/2024/images/thumbs/") == true)
        #expect(artist.fullImageUrl?.lastPathComponent.contains("©") == true)
        #expect(provider.loadBrowseTaxonomy().isEmpty)
        #expect(provider.loadArtistLinks().isEmpty)
    }

    @Test
    func loadingArchiveAndSwitchingBackPreservesCurrentProfileAndNewsState() async throws {
        let defaults = TestFixtures.isolatedUserDefaults()
        let settings = UserSettings(userDefaults: defaults)
        let profile = FestivalProfileStore(userDefaults: defaults, cloudKitEnabled: false)
        let artist = TestFixtures.artist(id: 176)
        let event = TestFixtures.event(
            id: 509, dayInJuly: 3, timeAsString: "18:00",
            stage: TestFixtures.stage(id: 24), artist: artist
        )
        profile.toggleSavedEvent(event)
        profile.setArtistRating(for: artist, rating: 3)
        profile.setArtistNote(for: artist, note: "Keep my 2026 note")
        settings.readNews = [42]
        let currentData = TestFixtures.festivalData(events: [event])
        let services = AppServices(
            userSettings: settings, festivalProfileStore: profile,
            festivalAdapter: FestivalRegistry.rudolstadt(year: 2026, source: FestivalDataProviderStub(
                cachedData: .loaded(currentData), refreshResult: .success(currentData)
            ), archive: false, includesSupplementaryInformation: false))
        var watchInputChanges = 0
        services.dataStore.onWatchSnapshotInputsChange = { watchInputChanges += 1 }

        settings.festivalEdition = .archive2024
        let archive = services.dataStore(for: settings.festivalEdition)
        await archive.loadFestivalContentForAppLaunch()
        guard case .success(let data) = archive.festivalData else {
            Issue.record("Expected a usable archive")
            return
        }
        #expect(data.events.contains { $0.id == 509 })
        #expect(data.festivalYear == 2024)
        #expect(archive.festivalProfileStore.isReadOnly)
        #expect(archive.festivalProfileStore.savedEvents.isEmpty)
        #expect(archive.festivalProfileStore.ratings.isEmpty)
        #expect(archive.festivalProfileStore.artistNotes.isEmpty)
        #expect(archive.festivalProfileStore.friendProfilesStore.profiles.isEmpty)
        #expect(archive.festivalDataProvenance?.source == .bundledArchive)
        #expect(archive.festivalDataFallbackStatus == nil)
        #expect(!archive.isUsingBundledFestivalDataBackup)
        #expect(watchInputChanges == 0)
        let presenter = SchedulePresenter(
            festivalData: data, recommendationState: .success([]),
            scheduleFilterType: .all, savedEventIds: [], positiveRatedArtistIds: []
        )
        guard case .success(let shownEvents) = presenter.shownEvents else {
            Issue.record("Expected the regular program presenter to accept the archive")
            return
        }
        #expect(shownEvents.count == 304)
        #expect(presenter.availableEventDays == [4, 5, 6, 7])
        settings.festivalEdition = .current
        #expect(services.dataStore(for: settings.festivalEdition) === services.dataStore)
        #expect(services.dataStore.festivalProfileStore === profile)

        #expect(profile.savedEvents == [509])
        #expect(profile.rating(for: artist.id) == 3)
        #expect(profile.noteText(for: artist) == "Keep my 2026 note")
        #expect(settings.readNews == [42])
        #expect(settings.festivalEdition == .current)
    }

    @Test
    func unavailableArchiveNeverUsesCurrentFestivalData() async {
        let archive = DataStore(
            edition: .archive2024,
            festivalAdapter: FestivalRegistry.rudolstadt(year: 2024, source: RudolstadtArchiveDataProvider(year: 1900), archive: true, includesSupplementaryInformation: false),
            loadInitialData: false
        )
        await archive.loadFestivalContentForAppLaunch()

        guard case .failure(.couldNotLoadFromFile) = archive.festivalData else {
            Issue.record("Expected explicit archive failure")
            return
        }
    }

    @Test
    func wrongYearFromAnInjectedProviderIsRejected() async {
        let currentData = TestFixtures.festivalData(events: [])
        let archive = DataStore(
            edition: .archive2024,
            festivalAdapter: FestivalRegistry.rudolstadt(year: 2024, source: FestivalDataProviderStub(refreshResult: .success(currentData)), archive: true, includesSupplementaryInformation: false),
            loadInitialData: false
        )

        await archive.loadFestivalContentForAppLaunch()

        guard case .failure(.couldNotLoadFromFile) = archive.festivalData else {
            Issue.record("Expected the wrong festival year to be rejected")
            return
        }
    }

    @Test
    func archiveProfileCannotEditOrPersistPersonalData() async throws {
        let defaults = TestFixtures.isolatedUserDefaults()
        defaults.set([509], forKey: "2026/savedEvents")
        defaults.set([888], forKey: "2024/savedEvents")
        let before = defaults.dictionaryRepresentation() as NSDictionary
        let archive = FestivalProfileStore(
            userDefaults: defaults, readOnlyFestivalYear: 2024, cloudKitEnabled: true
        )
        let data = try await RudolstadtArchiveDataProvider(year: 2024).refresh()
        let artist = try #require(data.artists.first)
        let event = try #require(data.events.first)

        archive.toggleSavedEvent(event)
        archive.setArtistRating(for: artist, rating: 3)
        archive.setArtistIcon(for: artist, icon: "zzz")
        archive.setArtistNote(for: artist, note: "Must not be saved")
        archive.updateBadge(name: "Must not be saved", colorHex: "#000000")
        archive.persistCache(immediately: true)
        await archive.flushPendingPersistence()

        #expect(archive.savedEvents == [888])
        #expect(archive.ratings.isEmpty)
        #expect(archive.artistNotes.isEmpty)
        #expect(archive.badgeName.isEmpty)
        #expect(archive.pendingProfileRecords.isEmpty)
        #expect(archive.cacheSnapshot.currentProfile.festivalYear == 2024)
        #expect(before == defaults.dictionaryRepresentation() as NSDictionary)
    }

    @Test(arguments: ["wrongYear", "futureSchema", "duplicateID", "missingArtist", "invalidDate", "emptyProgram"])
    func invalidArchiveIsRejectedInsteadOfPartiallyDisplayed(problem: String) throws {
        let url = try #require(Bundle.main.url(forResource: "2024_archive", withExtension: "json"))
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        switch problem {
        case "wrongYear": json["year"] = 2026
        case "futureSchema": json["schemaVersion"] = 99
        case "duplicateID":
            var artists = try #require(json["artists"] as? [[String: Any]])
            artists.append(try #require(artists.first))
            json["artists"] = artists
        case "missingArtist", "invalidDate":
            var events = try #require(json["events"] as? [[String: Any]])
            events[0][problem == "missingArtist" ? "artist" : "day"] = 999
            json["events"] = events
        default: json["events"] = []
        }

        #expect(throws: (any Error).self) {
            try RudolstadtArchiveDataProvider.decode(JSONSerialization.data(withJSONObject: json), year: 2024)
        }
    }
}
