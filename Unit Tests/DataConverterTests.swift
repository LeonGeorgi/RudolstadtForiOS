import XCTest
@testable import Rudolstadt

final class DataConverterTests: XCTestCase {
    func testNewsItemConversionDecodesNumericCharacterReferences() {
        let apiNewsItem = APINewsItem(
            id: 42,
            title: "Interview &#40;extended&#41;",
            language: "en",
            teaser: "Quote: &#34;Hello&#34;",
            text: "Hex works too: &#x28;test&#x29;",
            time: APITime(
                date: "2025-07-06 14:00:00.000000",
                timezoneType: 3,
                timezone: "Europe/Berlin"
            )
        )

        let newsItem = convertAPINewsItemToNewsItem(apiNewsItem: apiNewsItem)

        XCTAssertEqual(newsItem.shortDescription, "Interview (extended)")
        XCTAssertEqual(newsItem.longDescription, "Quote: \"Hello\"")
        XCTAssertEqual(newsItem.content, "Hex works too: (test)")
    }

    func testCountryParserHandlesMultipleEnglishCountries() {
        XCTAssertEqual(
            parseArtistCountryCodes("Germany / Burkina Faso"),
            ["DEU", "BFA"]
        )
        XCTAssertEqual(
            parseArtistCountryCodes("USA, Mexico and Canada"),
            ["USA", "MEX", "CAN"]
        )
    }

    func testCountryParserHandlesGermanAndAliasNames() {
        XCTAssertEqual(
            parseArtistCountryCodes("Deutschland, Österreich und Schweiz"),
            ["DEU", "AUT", "CHE"]
        )
        XCTAssertEqual(
            parseArtistCountryCodes("Scotland & Germany"),
            ["GBR", "DEU"]
        )
    }

    func testCountryParserHandlesApiProvidedAlpha3CodesAndAliases() {
        XCTAssertEqual(
            parseArtistCountryCodes("DEU"),
            ["DEU"]
        )
        XCTAssertEqual(
            parseArtistCountryCodes("JAP | DEU"),
            ["JPN", "DEU"]
        )
        XCTAssertEqual(
            parseArtistCountryCodes("ENG"),
            ["GBR"]
        )
        XCTAssertEqual(
            parseArtistCountryCodes("SUI"),
            ["CHE"]
        )
        XCTAssertEqual(
            parseArtistCountryCodes("POR"),
            ["PRT"]
        )
        XCTAssertEqual(
            parseArtistCountryCodes("SAF"),
            ["ZAF"]
        )
    }

    func testArtistConversionParsesStructuredCountryCodes() {
        let artist = convertAPIArtistToArtist(
            apiArtist: APIArtist(
                id: 10,
                category: .concert,
                hideArtist: false,
                name: "Test Artist",
                country: "Côte d’Ivoire / France",
                website: nil,
                video: nil,
                facebook: nil,
                instagram: nil,
                soundcloud: nil,
                imgThumb: "/thumb.jpg",
                imgFull: "/full.jpg",
                descriptionDE: "",
                descriptionEN: ""
            ),
            extraData: .empty(),
            tags: [],
            events: []
        )

        XCTAssertEqual(artist.countryCodes, ["CIV", "FRA"])
    }

    func testAttributedStringWithDetectedLinksMarksPlainURLsAsLinks() {
        let attributedString = attributedStringWithDetectedLinks(
            "Read more at https://example.com/news"
        )

        let runsWithLinks = attributedString.runs.compactMap(\.link)

        XCTAssertEqual(
            runsWithLinks,
            [URL(string: "https://example.com/news")!]
        )
    }

    func testExtractYouTubeVideoIDSupportsWatchAndShortLinks() {
        XCTAssertEqual(
            extractYouTubeVideoID(
                from: URL(string: "https://www.youtube.com/watch?v=QNJL6nfu__Q")!
            ),
            "QNJL6nfu__Q"
        )
        XCTAssertEqual(
            extractYouTubeVideoID(
                from: URL(string: "https://youtu.be/YO1ERhWMeXc")!
            ),
            "YO1ERhWMeXc"
        )
        XCTAssertEqual(
            extractYouTubeVideoID(
                from: URL(string: "https://www.youtube.com/shorts/abc123XYZ_9")!
            ),
            "abc123XYZ_9"
        )
    }

    func testDetectedURLsDeduplicatesAcrossMultipleStrings() {
        let urls = detectedURLs(
            in: [
                "https://example.com",
                "Video https://youtu.be/YO1ERhWMeXc",
                "Duplicate https://example.com",
            ]
        )

        XCTAssertEqual(
            urls.map(\.absoluteString),
            [
                "https://example.com",
                "https://youtu.be/YO1ERhWMeXc",
            ]
        )
    }

    func testAttributedStringWithDetectedLinksAndArtistMentionsAddsArtistLink() {
        let artist = Artist(
            id: 77,
            hiddenFromArtistList: false,
            artistType: .stage,
            someNumber: 0,
            name: "BandAdriatica",
            countries: "CH",
            countryCodes: ["CHE"],
            url: nil,
            facebookID: nil,
            youtubeID: nil,
            instagram: nil,
            descriptionGerman: nil,
            descriptionEnglish: nil,
            thumbImageUrlString: "",
            fullImageUrlString: "",
            ai: nil
        )
        let attributedString = attributedStringWithDetectedLinksAndArtistMentions(
            "Tonight: BandAdriatica live",
            artists: [artist]
        )

        XCTAssertTrue(
            attributedString.runs.contains { run in
                run.link == inlineArtistLinkURL(for: artist)
            }
        )
    }

    func testAttributedStringWithDetectedLinksAndArtistMentionsLinksOnlyFirstOccurrence() {
        let artist = Artist(
            id: 78,
            hiddenFromArtistList: false,
            artistType: .stage,
            someNumber: 0,
            name: "BandAdriatica",
            countries: "CH",
            countryCodes: ["CHE"],
            url: nil,
            facebookID: nil,
            youtubeID: nil,
            instagram: nil,
            descriptionGerman: nil,
            descriptionEnglish: nil,
            thumbImageUrlString: "",
            fullImageUrlString: "",
            ai: nil
        )
        let attributedString = attributedStringWithDetectedLinksAndArtistMentions(
            "BandAdriatica meets BandAdriatica after the show",
            artists: [artist]
        )

        let artistLinks = attributedString.runs.compactMap(\.link).filter { link in
            link == inlineArtistLinkURL(for: artist)
        }

        XCTAssertEqual(artistLinks.count, 1)
    }
}

final class NewsMentionMatchingTests: XCTestCase {
    func testWholeMentionMatchRequiresBoundaryBefore() {
        let normalizedText = normalizeForNewsMentionMatch(
            "superBandAdriatica opens the night"
        )

        XCTAssertNil(
            firstWholeMentionAppearanceIndex(
                in: normalizedText,
                candidate: "BandAdriatica"
            )
        )
    }

    func testWholeMentionMatchRequiresBoundaryAfter() {
        let normalizedText = normalizeForNewsMentionMatch(
            "BandAdriaticax returns for an encore"
        )

        XCTAssertNil(
            firstWholeMentionAppearanceIndex(
                in: normalizedText,
                candidate: "BandAdriatica"
            )
        )
    }

    func testArtistMentionRangesRequireWordBoundaries() {
        let ranges = artistMentionRanges(
            in: "superBandAdriatica opens for BandAdriatica.",
            candidate: "BandAdriatica"
        )

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(
            String("superBandAdriatica opens for BandAdriatica."[ranges[0]]),
            "BandAdriatica"
        )
    }

    func testWholeMentionMatchRejectsPartialTrailingWordMatch() {
        let normalizedText = normalizeForNewsMentionMatch(
            "La Nina headlines the evening"
        )

        XCTAssertNil(
            firstWholeMentionAppearanceIndex(
                in: normalizedText,
                candidate: "La Ni"
            )
        )
    }

    func testWholeMentionMatchAllowsNormalizedPunctuationAndDiacritics() {
        let normalizedText = normalizeForNewsMentionMatch(
            "Tonight: La Nina!"
        )

        XCTAssertEqual(
            firstWholeMentionAppearanceIndex(
                in: normalizedText,
                candidate: "La Niña"
            ),
            8
        )
    }
}

@MainActor
final class NewsServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetStoredNewsSettings()
    }

    override func tearDown() {
        resetStoredNewsSettings()
        super.tearDown()
    }

    func testLoadNewsUsesFreshCacheWithoutFetching() async {
        let cachedNews = [makeNewsItem(id: 7, languageCode: "en")]
        let cache = NewsCacheStub(loadResult: .loaded(cachedNews))
        let apiClient = NewsAPIStub()
        let settings = UserSettings()
        let service = NewsService(
            dataLoader: cache,
            apiClient: apiClient,
            userSettings: settings,
            notifier: NewsNotifierStub()
        )

        let result = await service.loadNews()

        guard case .success(let news) = result else {
            return XCTFail("Expected cached news")
        }
        XCTAssertEqual(news.map(\.id), [7])
        XCTAssertEqual(apiClient.fetchCallCount, 0)
    }

    func testRefreshNewsIfNecessaryFetchesMissingCacheAndMarksItemsAsOld() async {
        let apiNews = [
            makeAPINewsItem(id: 10, language: "en"),
            makeAPINewsItem(id: 11, language: "de"),
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
            return XCTFail("Expected fetched news")
        }
        XCTAssertEqual(news.map(\.id), [10, 11])
        XCTAssertEqual(apiClient.fetchCallCount, 1)
        XCTAssertEqual(cache.storedNewsIds, [10, 11])
        XCTAssertEqual(settings.oldNews, [10, 11])
        XCTAssertTrue(notifier.notifiedItemIds.isEmpty)
    }

    func testBackgroundRefreshNotifiesOnlyNewItemsInCurrentLanguage() async {
        let apiNews = [
            makeAPINewsItem(id: 1, language: "en"),
            makeAPINewsItem(id: 2, language: "en"),
            makeAPINewsItem(id: 3, language: "de"),
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

        XCTAssertEqual(notifier.notifiedItemIds, [2])
        XCTAssertEqual(settings.oldNews, [1, 2])
    }

    private func resetStoredNewsSettings() {
        let settings = UserSettings()
        settings.oldNews = []
    }

    private func makeAPINewsItem(id: Int, language: String) -> APINewsItem {
        APINewsItem(
            id: id,
            title: "Title \(id)",
            language: language,
            teaser: "Teaser \(id)",
            text: "Text \(id)",
            time: APITime(
                date: "2025-07-06 14:00:00.000000",
                timezoneType: 3,
                timezone: "Europe/Berlin"
            )
        )
    }

    private func makeNewsItem(id: Int, languageCode: String) -> NewsItem {
        NewsItem(
            id: id,
            languageCode: languageCode,
            dateAsString: "06.07.2025",
            timeAsString: "14:00",
            shortDescription: "Short \(id)",
            longDescription: "Long \(id)",
            content: "Content \(id)"
        )
    }
}

private final class NewsAPIStub: NewsFetching {
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

private final class NewsCacheStub: NewsCaching {
    let loadResult: FileLoadingResult<[NewsItem]>
    var storedNewsIds: [Int] = []
    var isFileOlderThanReturnValue = true

    init(loadResult: FileLoadingResult<[NewsItem]>) {
        self.loadResult = loadResult
    }

    func loadNewsFromFile() -> FileLoadingResult<[NewsItem]> {
        loadResult
    }

    func storeAPINewsToFile(news: [APINewsItem], fileName: String) -> Bool {
        storedNewsIds = news.map(\.id)
        return true
    }

    func isFileOlderThan(fileName: String, date: Date?) -> Bool {
        isFileOlderThanReturnValue
    }
}

private final class NewsNotifierStub: NewsNotifying {
    var notifiedItemIds: [Int] = []

    func notifyUser(of item: NewsItem) async throws {
        notifiedItemIds.append(item.id)
    }
}

final class RecommendationServiceTests: XCTestCase {
    func testEstimateEventDurationsUsesFollowingStageEventGap() {
        let stage = makeStage(id: 1, stageNumber: 1)
        let artistOne = makeArtist(id: 1)
        let artistTwo = makeArtist(id: 2)
        let events = [
            makeEvent(id: 101, dayInJuly: 3, timeAsString: "10:00", stage: stage, artist: artistOne),
            makeEvent(id: 102, dayInJuly: 3, timeAsString: "11:00", stage: stage, artist: artistTwo),
        ]
        let service = RecommendationService()

        let durations = service.estimateEventDurations(events: events)

        XCTAssertEqual(durations[101], 30)
        XCTAssertEqual(durations[102], 60)
    }

    func testBuildSnapshotReturnsNoRecommendationsWithoutPositiveRatings() {
        let festivalData = makeFestivalData(events: [
            makeEvent(id: 201, dayInJuly: 3, timeAsString: "18:00", stage: makeStage(id: 2), artist: makeArtist(id: 21))
        ])
        let service = RecommendationService()

        let snapshot = service.buildSnapshot(
            data: festivalData,
            savedEventIds: [],
            ratings: [:],
            now: makeDate(dayInJuly: 3, hour: 12, minute: 0)
        )

        XCTAssertEqual(snapshot.recommendedEventIds, [])
    }

    func testBuildSnapshotDoesNotRecommendSameArtistWhenOneEventIsAlreadySaved() {
        let artist = makeArtist(id: 22)
        let stage = makeStage(id: 3)
        let festivalData = makeFestivalData(events: [
            makeEvent(id: 301, dayInJuly: 3, timeAsString: "18:00", stage: stage, artist: artist),
            makeEvent(id: 302, dayInJuly: 3, timeAsString: "20:00", stage: stage, artist: artist),
        ])
        let service = RecommendationService()

        let snapshot = service.buildSnapshot(
            data: festivalData,
            savedEventIds: [301],
            ratings: ["22": 3],
            now: makeDate(dayInJuly: 3, hour: 12, minute: 0)
        )

        XCTAssertEqual(snapshot.recommendedEventIds, [])
    }

    func testBuildSnapshotKeepsSingleBestEventPerArtist() {
        let artist = makeArtist(id: 23)
        let stage = makeStage(id: 4)
        let festivalData = makeFestivalData(events: [
            makeEvent(id: 401, dayInJuly: 3, timeAsString: "18:00", stage: stage, artist: artist),
            makeEvent(id: 402, dayInJuly: 3, timeAsString: "20:00", stage: stage, artist: artist),
        ])
        let service = RecommendationService()

        let snapshot = service.buildSnapshot(
            data: festivalData,
            savedEventIds: [],
            ratings: ["23": 2],
            now: makeDate(dayInJuly: 3, hour: 12, minute: 0)
        )

        XCTAssertEqual(snapshot.recommendedEventIds, [401])
    }

    func testBuildSnapshotChoosesHigherRatedEventWhenTwoEventsConflict() {
        let stage = makeStage(id: 5)
        let festivalData = makeFestivalData(events: [
            makeEvent(id: 501, dayInJuly: 3, timeAsString: "18:00", stage: stage, artist: makeArtist(id: 24)),
            makeEvent(id: 502, dayInJuly: 3, timeAsString: "18:00", stage: stage, artist: makeArtist(id: 25)),
        ])
        let service = RecommendationService()

        let snapshot = service.buildSnapshot(
            data: festivalData,
            savedEventIds: [],
            ratings: ["24": 3, "25": 1],
            now: makeDate(dayInJuly: 3, hour: 12, minute: 0)
        )

        XCTAssertEqual(snapshot.recommendedEventIds, [501])
    }

    func testBuildSnapshotIgnoresPastEvents() {
        let stage = makeStage(id: 6)
        let festivalData = makeFestivalData(events: [
            makeEvent(id: 601, dayInJuly: 3, timeAsString: "10:00", stage: stage, artist: makeArtist(id: 26)),
            makeEvent(id: 602, dayInJuly: 3, timeAsString: "18:00", stage: stage, artist: makeArtist(id: 27)),
        ])
        let service = RecommendationService()

        let snapshot = service.buildSnapshot(
            data: festivalData,
            savedEventIds: [],
            ratings: ["26": 3, "27": 3],
            now: makeDate(dayInJuly: 3, hour: 12, minute: 0)
        )

        XCTAssertEqual(snapshot.recommendedEventIds, [602])
    }

    func testBuildSnapshotIsStableForUnchangedInputs() {
        let stage = makeStage(id: 7)
        let festivalData = makeFestivalData(events: [
            makeEvent(id: 701, dayInJuly: 3, timeAsString: "18:00", stage: stage, artist: makeArtist(id: 28))
        ])
        let service = RecommendationService()
        let now = makeDate(dayInJuly: 3, hour: 12, minute: 0)

        let first = service.buildSnapshot(
            data: festivalData,
            savedEventIds: [],
            ratings: ["28": 2],
            now: now
        )
        let second = service.buildSnapshot(
            data: festivalData,
            savedEventIds: [],
            ratings: ["28": 2],
            now: now
        )

        XCTAssertEqual(first, second)
    }
}

final class RecommendationSchedulePresenterTests: XCTestCase {
    func testOptimalFilterShowsSavedAndRecommendedEvents() {
        let events = [
            makeEvent(id: 801, dayInJuly: 3, timeAsString: "18:00", stage: makeStage(id: 8), artist: makeArtist(id: 31)),
            makeEvent(id: 802, dayInJuly: 3, timeAsString: "19:00", stage: makeStage(id: 9), artist: makeArtist(id: 32)),
            makeEvent(id: 803, dayInJuly: 3, timeAsString: "20:00", stage: makeStage(id: 10), artist: makeArtist(id: 33)),
        ]
        let presenter = RecommendationSchedulePresenter(
            dataState: .success(makeFestivalData(events: events)),
            recommendationState: .success([802]),
            scheduleFilterType: .optimal,
            savedEventIds: [801],
            positiveRatedArtistIds: []
        )

        guard case .success(let shownEvents) = presenter.shownEvents else {
            return XCTFail("Expected shown events")
        }
        XCTAssertEqual(shownEvents.map(\.id), [801, 802])
    }

    func testInterestingFilterShowsSavedAndPositiveRatedArtists() {
        let events = [
            makeEvent(id: 811, dayInJuly: 3, timeAsString: "18:00", stage: makeStage(id: 11), artist: makeArtist(id: 34)),
            makeEvent(id: 812, dayInJuly: 3, timeAsString: "19:00", stage: makeStage(id: 12), artist: makeArtist(id: 35)),
            makeEvent(id: 813, dayInJuly: 3, timeAsString: "20:00", stage: makeStage(id: 13), artist: makeArtist(id: 36)),
        ]
        let presenter = RecommendationSchedulePresenter(
            dataState: .success(makeFestivalData(events: events)),
            recommendationState: .loading,
            scheduleFilterType: .interesting,
            savedEventIds: [811],
            positiveRatedArtistIds: [35]
        )

        guard case .success(let shownEvents) = presenter.shownEvents else {
            return XCTFail("Expected shown events")
        }
        XCTAssertEqual(shownEvents.map(\.id), [811, 812])
    }

    func testSavedFilterShowsOnlySavedEvents() {
        let events = [
            makeEvent(id: 821, dayInJuly: 3, timeAsString: "18:00", stage: makeStage(id: 14), artist: makeArtist(id: 37)),
            makeEvent(id: 822, dayInJuly: 3, timeAsString: "19:00", stage: makeStage(id: 15), artist: makeArtist(id: 38)),
        ]
        let presenter = RecommendationSchedulePresenter(
            dataState: .success(makeFestivalData(events: events)),
            recommendationState: .loading,
            scheduleFilterType: .saved,
            savedEventIds: [822],
            positiveRatedArtistIds: []
        )

        guard case .success(let shownEvents) = presenter.shownEvents else {
            return XCTFail("Expected shown events")
        }
        XCTAssertEqual(shownEvents.map(\.id), [822])
    }

    func testAllFilterShowsAllEvents() {
        let events = [
            makeEvent(id: 831, dayInJuly: 3, timeAsString: "18:00", stage: makeStage(id: 16), artist: makeArtist(id: 39)),
            makeEvent(id: 832, dayInJuly: 3, timeAsString: "19:00", stage: makeStage(id: 17), artist: makeArtist(id: 40)),
        ]
        let presenter = RecommendationSchedulePresenter(
            dataState: .success(makeFestivalData(events: events)),
            recommendationState: .loading,
            scheduleFilterType: .all,
            savedEventIds: [],
            positiveRatedArtistIds: []
        )

        guard case .success(let shownEvents) = presenter.shownEvents else {
            return XCTFail("Expected shown events")
        }
        XCTAssertEqual(shownEvents.map(\.id), [831, 832])
    }
}

@MainActor
final class RecommendationDataStoreTests: XCTestCase {
    func testRefreshRecommendationsStaysLoadingWithoutFestivalData() async {
        let settings = UserSettings()
        let store = DataStore(
            userSettings: settings,
            recommendationService: RecommendationServiceStub(
                snapshot: RecommendationSnapshot(
                    recommendedEventIds: [901],
                    estimatedEventDurations: [901: 60]
                )
            )
        )
        await store.refreshRecommendations(
            now: makeDate(dayInJuly: 3, hour: 12, minute: 0)
        )

        if case .loading = store.recommendedEvents {
            XCTAssertNil(store.estimatedEventDurations)
        } else {
            XCTFail("Expected loading state")
        }
    }

    func testRefreshRecommendationsPublishesServiceSnapshot() async {
        let settings = UserSettings()
        let snapshot = RecommendationSnapshot(
            recommendedEventIds: [902, 903],
            estimatedEventDurations: [902: 60, 903: 90]
        )
        let store = DataStore(
            userSettings: settings,
            recommendationService: RecommendationServiceStub(snapshot: snapshot)
        )
        store.data = .success(makeFestivalData(events: [
            makeEvent(id: 902, dayInJuly: 3, timeAsString: "18:00", stage: makeStage(id: 18), artist: makeArtist(id: 41)),
            makeEvent(id: 903, dayInJuly: 3, timeAsString: "20:00", stage: makeStage(id: 19), artist: makeArtist(id: 42)),
        ]))

        await store.refreshRecommendations(
            now: makeDate(dayInJuly: 3, hour: 12, minute: 0)
        )

        if case .success(let ids) = store.recommendedEvents {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(ids, snapshot.recommendedEventIds)
            XCTAssertEqual(
                store.estimatedEventDurations,
                snapshot.estimatedEventDurations
            )
        } else {
            XCTFail("Expected recommendation success state")
        }
    }
}

@MainActor
final class UserSettingsChangeTests: XCTestCase {
    func testRecommendationInputChangeFiresForSavedEventsAndRatings() {
        let settings = UserSettings()
        var callbackCount = 0
        settings.onChange(of: .recommendationInputs) {
            callbackCount += 1
        }

        settings.toggleSavedEvent(Event.example)
        settings.setArtistRating(for: Artist.example, rating: 2)

        XCTAssertEqual(callbackCount, 2)
    }

    func testRecommendationInputChangeDoesNotFireForReadNewsUpdates() {
        let settings = UserSettings()
        var callbackCount = 0
        settings.onChange(of: .recommendationInputs) {
            callbackCount += 1
        }

        settings.markNewsAsRead(
            NewsItem(
                id: 12,
                languageCode: "en",
                dateAsString: "06.07.2025",
                timeAsString: "14:00",
                shortDescription: "Short 12",
                longDescription: "Long 12",
                content: "Content 12"
            )
        )

        XCTAssertEqual(callbackCount, 0)
    }
}

private final class RecommendationServiceStub: RecommendationProviding {
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

private func makeFestivalData(events: [Event]) -> FestivalData {
    FestivalData(
        artists: unique(events.map(\.artist), by: \.id),
        areas: unique(events.map(\.stage.area), by: \.id),
        stages: unique(events.map(\.stage), by: \.id),
        events: events
    )
}

private func makeArtist(id: Int, name: String? = nil) -> Artist {
    Artist(
        id: id,
        hiddenFromArtistList: false,
        artistType: .stage,
        someNumber: 0,
        name: name ?? "Artist \(id)",
        countries: "Germany",
        countryCodes: ["DEU"],
        url: nil,
        facebookID: nil,
        youtubeID: nil,
        instagram: nil,
        descriptionGerman: nil,
        descriptionEnglish: nil,
        thumbImageUrlString: "https://example.com/thumb.jpg",
        fullImageUrlString: "https://example.com/full.jpg",
        ai: nil
    )
}

private func makeStage(id: Int, stageNumber: Int? = nil) -> Stage {
    Stage(
        id: id,
        germanName: "Stage \(id)",
        englishName: "Stage \(id)",
        germanDescription: nil,
        englishDescription: nil,
        stageNumber: stageNumber,
        latitude: 50.0 + Double(id) * 0.001,
        longitude: 11.0 + Double(id) * 0.001,
        area: .example,
        stageType: .festivalTicket
    )
}

private func makeEvent(
    id: Int,
    dayInJuly: Int,
    timeAsString: String,
    stage: Stage,
    artist: Artist,
    tag: Tag? = nil
) -> Event {
    Event(
        id: id,
        dayInJuly: dayInJuly,
        timeAsString: timeAsString,
        stage: stage,
        artist: artist,
        tag: tag
    )
}

private func makeDate(dayInJuly: Int, hour: Int, minute: Int) -> Date {
    Calendar.current.date(
        from: DateComponents(
            year: DataStore.year,
            month: 7,
            day: dayInJuly,
            hour: hour,
            minute: minute
        )
    )!
}

private func unique<T, Key: Hashable>(_ values: [T], by keyPath: KeyPath<T, Key>) -> [T] {
    var seen = Set<Key>()
    return values.filter { value in
        seen.insert(value[keyPath: keyPath]).inserted
    }
}
