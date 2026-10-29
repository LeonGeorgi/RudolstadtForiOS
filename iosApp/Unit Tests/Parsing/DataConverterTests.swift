import RudolstadtCore
import Foundation
import Testing
@testable import Rudolstadt

struct DataConverterTests {
    @Test
    @MainActor
    func timelineAdapterKeepsSharedEventIdentity() throws {
        let event = TestFixtures.event(id: 42, dayInJuly: 4, timeAsString: "12:15", stage: TestFixtures.stage(id: 1), artist: TestFixtures.artist(id: 1))
        let timeline = ProgramTimeline.shared.build(
            events: [event], durations: [42: 60].coreMinutes, zone: "Europe/Berlin",
            alignedColumns: true, longerFirst: true,
            placePrecedes: { KotlinBoolean(bool: Stage.precedes($0, $1)) })
        let locale = Locale(identifier: "de_DE")
        let formatter = ListFormatter()
        formatter.locale = locale
        let columns = timeline.nativeColumns(locale: locale) { event in
            ScheduleTimelineEventPresentation(
                event: event, duration: 60,
                contextPreviewState: EventContextPreviewState(
                    isSaved: false, artistRating: 0, artistIconName: nil,
                    friendProfilesWhoSavedEvent: [], artistNote: nil,
                    isArtistSummaryEnabled: true),
                locale: locale, colorScheme: .light, countryFormatter: formatter)
        }
        guard case .event(let shown) = columns.first?.items.first else {
            Issue.record("Expected the original shared event in the native timeline")
            return
        }
        #expect(shown.event === event)
        #expect(timeline.nativeTicks.count == 4)
    }

    @Test
    func stageConversionFallsBackWhenAreaIsMissing() throws {
        let stage = try KotlinCore.bridge.convertPlace(
            sourceJSON: #"{"id":44,"title":"Lutherkirche","title_en":"Lutherkirche","lat":50.719038,"lon":11.327535,"area":0,"category":"comboticket","map_number":8}"#,
            year: 2026, areas: [Area(id: 2, germanName: "Heinepark", englishName: "Heinepark"),
                               Area(id: 3, germanName: "Innenstadt", englishName: "Inner City")])

        #expect(stage.area?.id == 0)
        #expect(stage.area?.germanName == "Sonstige Orte")
        #expect(stage.area?.englishName == "Other locations")
    }

    @Test
    func newsItemConversionDecodesNumericCharacterReferences() {
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

        #expect(newsItem.shortDescription == "Interview (extended)")
        #expect(newsItem.longDescription == "Quote: \"Hello\"")
        #expect(newsItem.content == "Hex works too: (test)")
    }

    @Test
    func countryParserHandlesMultipleEnglishCountries() {
        #expect(
            parseArtistCountryCodes("Germany / Burkina Faso")
                == ["DEU", "BFA"]
        )
        #expect(
            parseArtistCountryCodes("USA, Mexico and Canada")
                == ["USA", "MEX", "CAN"]
        )
    }

    @Test
    func countryParserHandlesGermanAndAliasNames() {
        #expect(
            parseArtistCountryCodes("Deutschland, Österreich und Schweiz")
                == ["DEU", "AUT", "CHE"]
        )
        #expect(
            parseArtistCountryCodes("Scotland & Germany")
                == ["GBR", "DEU"]
        )
    }

    @Test
    func localizedCountryNameUsesExplicitLocale() {
        #expect(
            localizedCountryName(
                forRegionCode: "DEU",
                locale: Locale(identifier: "de_DE")
            ) == "Deutschland"
        )
        #expect(
            localizedCountryName(
                forRegionCode: "DEU",
                locale: Locale(identifier: "en_US")
            ) == "Germany"
        )
    }

    @Test
    func artistCountryDescriptionKeepsUKNationsSeparate() {
        let countries = localizedArtistCountries(
            rawValue: "Scotland & England",
            countryCodes: ["GBR"],
            locale: Locale(identifier: "de_DE")
        )

        #expect(countries.map(\.name) == ["Schottland", "England"])
        #expect(countries.map(\.countryCode) == ["GBR", "GBR"])
        #expect(
            localizedArtistCountryDescription(
                rawValue: "Scotland & England",
                countryCodes: ["GBR"],
                locale: Locale(identifier: "de_DE")
            ) == "Schottland und England"
        )
        #expect(
            localizedArtistCountryDescription(
                rawValue: "SCO / Northern Ireland / Wales",
                countryCodes: ["GBR"],
                locale: Locale(identifier: "en_US")
            ) == "Scotland, Northern Ireland, and Wales"
        )
    }

    @Test
    func artistCountryDescriptionStillLocalizesRegularCountries() {
        #expect(
            localizedArtistCountryDescription(
                rawValue: "Scotland & Germany",
                countryCodes: ["GBR", "DEU"],
                locale: Locale(identifier: "de_DE")
            ) == "Schottland und Deutschland"
        )
        #expect(
            localizedArtistCountryNames(
                rawValue: "Scotland & Germany",
                countryCodes: ["GBR", "DEU"],
                locale: Locale(identifier: "de_DE")
            ) == ["Schottland", "Deutschland"]
        )
    }

    @Test
    func countryParserHandlesAPIProvidedAlpha3CodesAndAliases() {
        #expect(parseArtistCountryCodes("DEU") == ["DEU"])
        #expect(parseArtistCountryCodes("JAP | DEU") == ["JPN", "DEU"])
        #expect(parseArtistCountryCodes("ENG") == ["GBR"])
        #expect(parseArtistCountryCodes("SUI") == ["CHE"])
        #expect(parseArtistCountryCodes("POR") == ["PRT"])
        #expect(parseArtistCountryCodes("DEN") == ["DNK"])
        #expect(parseArtistCountryCodes("SAF") == ["ZAF"])
        #expect(parseArtistCountryCodes("LAT") == ["LVA"])
        #expect(parseArtistCountryCodes("KOS") == ["XKX"])
        #expect(parseArtistCountryCodes("Kosovo") == ["XKX"])

        let denmark = localizedArtistCountries(
            rawValue: "DEN",
            countryCodes: [],
            locale: Locale(identifier: "de_DE")
        )
        #expect(denmark.map(\.name) == ["Dänemark"])
        #expect(denmark.map(\.countryCode) == ["DNK"])
    }

    @Test
    func worldMapIncludesCountriesFromDetailMap() throws {
        let overview = try WorldCountryOverlayStore.buildLoadedMap(
            resourceNames: ["world_countries"]
        )
        let detail = try WorldCountryOverlayStore.buildLoadedMap(
            resourceNames: ["world_countries_detail"]
        )
        let overviewCodes = Set(overview.overlayMetadataByID.values.map(\.code))
        let detailCodes = Set(detail.overlayMetadataByID.values.map(\.code))

        #expect(detailCodes.isSubset(of: overviewCodes))
        #expect(overviewCodes.contains("XKX"))
        #expect(!overviewCodes.contains("KOS"))
    }

    @Test
    func worldMapCoversBundledArtistsWithCountryData() throws {
        let url = try #require(Bundle.main.url(
                forResource: "\(FestivalConfiguration.year)_rudolstadt_data", withExtension: "json"
            ))
        let apiData = try TestFixtures.sourcePayload(Data(contentsOf: url))
        let program = try convertFestivalSourceToEntities(apiData: apiData, extraData: .empty())
        let map = try WorldCountryOverlayStore.buildLoadedMap(resourceNames: ["world_countries"])
        let countryCodes = Set(map.overlayMetadataByID.values.map(\.code))

        for artist in program.artists where !artist.hiddenFromArtistList {
            let country = artist.countries
            guard !country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let codes = artist.countryCodes
            #expect(!codes.isEmpty, "Unrecognized country for \(artist.name): \(country)")
            #expect(Set(codes).isSubset(of: countryCodes), "Missing country for \(artist.name)")
        }
    }

    @Test
    func countryFlagsUseNormalizedCountryCodes() {
        #expect(emojiFlag(forRegionCode: "DEU") == "🇩🇪")
        #expect(emojiFlag(forRegionCode: "DEN") == "🇩🇰")
        #expect(emojiFlag(forRegionCode: "GBR") == "🇬🇧")
        #expect(emojiFlag(forRegionCode: "not-a-country") == nil)
    }

    @Test
    func artistConversionParsesStructuredCountryCodes() throws {
        let artist = try KotlinCore.bridge.convertArtist(
            sourceJSON: #"{"id":10,"name":"Test Artist","category":"concert","country":"Côte d’Ivoire / France"}"#,
            extraJSON: "{}", tagsJSON: "[]", eventsJSON: "[]", year: 2026,
            fold: KotlinCore.foldProgramText)

        #expect(artist.countryCodes == ["CIV", "FRA"])
    }

    @Test
    func attributedStringMarksPlainURLsAsLinks() throws {
        let attributedString = attributedStringWithDetectedLinksAndArtistMentions(
            "Read more at https://example.com/news",
            artists: []
        )
        let expectedURL = try #require(URL(string: "https://example.com/news"))

        #expect(attributedString.runs.compactMap(\.link) == [expectedURL])
    }

    @Test
    func extractYouTubeVideoIDSupportsWatchAndShortLinks() throws {
        let watchURL = try #require(
            URL(string: "https://www.youtube.com/watch?v=QNJL6nfu__Q")
        )
        let shortURL = try #require(
            URL(string: "https://youtu.be/YO1ERhWMeXc")
        )
        let shortsURL = try #require(
            URL(string: "https://www.youtube.com/shorts/abc123XYZ_9")
        )

        #expect(extractYouTubeVideoID(from: watchURL) == "QNJL6nfu__Q")
        #expect(extractYouTubeVideoID(from: shortURL) == "YO1ERhWMeXc")
        #expect(extractYouTubeVideoID(from: shortsURL) == "abc123XYZ_9")
    }

    @Test
    func detectedURLsDeduplicatesAcrossMultipleStrings() {
        let urls = detectedURLs(
            in: [
                "https://example.com",
                "Video https://youtu.be/YO1ERhWMeXc",
                "Duplicate https://example.com",
            ]
        )

        #expect(
            urls.map(\.absoluteString)
                == [
                    "https://example.com",
                    "https://youtu.be/YO1ERhWMeXc",
                ]
        )
    }

    @Test
    func attributedStringAddsArtistLink() {
        let artist = TestFixtures.artist(id: 77, name: "BandAdriatica")
        let attributedString = attributedStringWithDetectedLinksAndArtistMentions(
            "Tonight: BandAdriatica live",
            artists: [artist]
        )

        #expect(
            attributedString.runs.contains { run in
                run.link == inlineArtistLinkURL(for: artist)
            }
        )
    }

    @Test
    func attributedStringLinksOnlyFirstArtistOccurrence() {
        let artist = TestFixtures.artist(id: 78, name: "BandAdriatica")
        let attributedString = attributedStringWithDetectedLinksAndArtistMentions(
            "BandAdriatica meets BandAdriatica after the show",
            artists: [artist]
        )
        let artistLinks = attributedString.runs.compactMap(\.link).filter { link in
            link == inlineArtistLinkURL(for: artist)
        }

        #expect(artistLinks.count == 1)
    }
}

struct FestivalDataContractTests {
    private var eventJSON: String {
        """
        {"id":101,"start":{"date":"\(FestivalConfiguration.year)-07-04 01:30:00.000000","timezone_type":3,"timezone":"Europe/Berlin"},
         "day":"04.07.\(FestivalConfiguration.year)","time":"01:30","artist":11,"stage":22,"tags":[33]}
        """
    }

    private let artistJSON =
        #"{"id":11,"category":"concert","hide_artist":false,"name":"Band &#38; Co","img_thumb":"/thumb.jpg","img_full":"/full.jpg","description_de":"Deutsch","description_en":"English"}"#
    private let stageJSON =
        #"{"id":22,"title":"Bühne","title_en":"Stage","lat":50.72,"lon":11.34,"area":2,"category":"cityticket","map_number":7}"#

    private func fixture(events: String, artists: String? = nil, stages: String? = nil) throws
        -> RudolstadtPayload
    {
        let json = """
            {"areas":[{"id":2,"title":"Park","title_en":"Park"}],"artists":[\(artists ?? artistJSON)],
             "stages":[\(stages ?? stageJSON)],"tags":[{"id":33,"title":"Musik","title_en":"Music"}],"events":[\(events)]}
            """
        return try KotlinCore.bridge.decodeRudolstadtPayload(sourceJSON: json)
    }

    private func convert(_ api: RudolstadtPayload) throws -> FestivalData {
        try convertFestivalSourceToEntities(apiData: api, extraData: .empty())
    }

    @Test
    func literalWireKeysAndCanonicalStartArePreserved() throws {
        let api = try fixture(
            events: eventJSON.replacingOccurrences(
                of: "\"time\":\"01:30\"", with: "\"time\":\"20:00\""))
        let data = try convert(api)
        let event = try #require(data.events.first)
        #expect(event.id == 101)
        #expect(event.artist.formattedName == "Band & Co")
        #expect(event.artist.thumbImageUrlString.hasSuffix("/thumb.jpg"))
        #expect(event.stage.stageNumber == 7)
        #expect(event.stage.englishName == "Stage")
        #expect(event.stage.stageType == .festivalAndDayTicket)
        #expect(event.tag?.id == "33")
        #expect(event.timeAsString == "01:30")
        #expect(event.festivalDay == 3)
        #expect(event.startDate == TestFixtures.date(dayInJuly: 4, hour: 1, minute: 30))
        var tokyo = Calendar(identifier: .buddhist)
        tokyo.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        #expect(event.date(calendar: tokyo) == event.startDate)
        #expect(event.festivalDay(calendar: tokyo) == 3)
    }

    @Test
    func allResolvedEventTagsSurviveConversionAndCachingForHiddenArtists() throws {
        let source = try fixture(
            events: eventJSON.replacingOccurrences(of: "[33]", with: "[999,33,44]"),
            artists: artistJSON.replacingOccurrences(of: "false", with: "true")
        )
        let json = source.sourceJSON.replacingOccurrences(
            of: #""tags":[{"id":33,"title":"Musik","title_en":"Music"}]"#,
            with: #""tags":[{"id":33,"title":"Musik","title_en":"Music"},{"id":44,"title":"Vortrag","title_en":"Lecture"}]"#)
        let api = try KotlinCore.bridge.decodeRudolstadtPayload(sourceJSON: json)
        let cached = try KotlinCore.bridge.decodeRudolstadtPayload(sourceJSON: api.sourceJSON)
        let event = try #require(convert(cached).events.first)
        #expect(event.artist.hiddenFromArtistList)
        #expect(event.tags.map(\.id) == ["33", "44"])
        #expect(event.tag?.id == "33")
    }

    @Test
    func singleTagInitializersKeepTheSamePrimaryTag() throws {
        let event = Event.example
        let tag = try #require(event.tag)
        #expect(event.tags.map(\.id) == [tag.id])
    }

    @Test(arguments: ["concert", "dancing", "festival-plus", "new-category"])
    func artistCategoriesHaveAnExplicitFallback(raw: String) throws {
        let json = artistJSON.replacingOccurrences(of: "concert", with: raw)
        let api = try fixture(events: eventJSON, artists: json)
        #expect(try TestFixtures.sourceRecords(api, "artists").first?["category"] as? String == raw)
        let artist = try #require(try convert(api).artists.first)
        let expected: ArtistType = raw == "concert" ? .stage : raw == "dancing" ? .dance : .other
        #expect(artist.artistType == expected)
        let roundTrip = try KotlinCore.bridge.decodeRudolstadtPayload(sourceJSON: api.sourceJSON)
        #expect(try TestFixtures.sourceRecords(roundTrip, "artists").first?["category"] as? String == raw)
    }

    @Test(arguments: ["cityticket", "comboticket", "information", "future-ticket"])
    func stageCategoriesNeverDiscardTheProgram(raw: String) throws {
        let api = try fixture(
            events: eventJSON, stages: stageJSON.replacingOccurrences(of: "cityticket", with: raw))
        let stage = try #require(try convert(api).events.first?.stage)
        let expected: StageType =
            raw == "cityticket"
            ? .festivalAndDayTicket
            : raw == "comboticket" ? .festivalTicket : raw == "information" ? .other : .unknown
        #expect(stage.stageType == expected)
        #expect(stage.hasLocation)
        let roundTrip = try KotlinCore.bridge.decodeRudolstadtPayload(sourceJSON: api.sourceJSON)
        #expect(try TestFixtures.sourceRecords(roundTrip, "stages").first?["category"] as? String == raw)
    }

    @Test
    func missingReferencesKeepIdentityAndResolveAfterRefresh() throws {
        let api = try fixture(
            events: eventJSON + ","
                + eventJSON.replacingOccurrences(of: "101", with: "102")
                .replacingOccurrences(of: "\"artist\":11", with: "\"artist\":12")
                .replacingOccurrences(of: "\"stage\":22", with: "\"stage\":23"), artists: "",
            stages: "")
        let data = try convert(api)
        #expect(Set(data.events.map(\.id)) == [101, 102])
        #expect(Set(data.artists.map(\.id)) == [11, 12])
        #expect(Set(data.stages.map(\.id)) == [22, 23])
        #expect(data.artists.allSatisfy { !$0.isMetadataAvailable && $0.thumbImageUrl == nil })
        #expect(data.stages.allSatisfy { !$0.isMetadataAvailable && !$0.hasLocation })
        #expect(data.events.allSatisfy { !$0.hasCompleteMetadata })
        #expect(
            data.artists.first?.displayName(locale: Locale(identifier: "de"))
                == "Künstler unbekannt")
        #expect(
            data.artists.first?.displayName(locale: Locale(identifier: "en")) == "Artist unknown")
        let resolved = try #require(convert(fixture(events: eventJSON)).events.first)
        #expect(resolved.id == data.events.first?.id)
        #expect(resolved.artist.id == 11 && resolved.stage.id == 22)
        #expect(resolved.hasCompleteMetadata)
    }

    @Test
    func absentMetadataAndBadRecordsDoNotPoisonValidEventsOrTheCache() throws {
        let api = try fixture(events: eventJSON + #",{"id":102},{"id":"broken"},null,17"#)
        #expect(api.omittedRecordCount == 3)
        let cached = try KotlinCore.bridge.decodeRudolstadtPayload(sourceJSON: api.sourceJSON)
        let data = try convert(cached)
        #expect(data.omittedRecordCount == 3)
        #expect(Set(data.events.map(\.id)) == [101, 102])
        let unknown = try #require(data.events.first { $0.id == 102 })
        #expect(unknown.startDate == nil && unknown.knownDate == nil)
        #expect(!unknown.artist.isMetadataAvailable && !unknown.stage.isMetadataAvailable)
        #expect(unknown.artist.id < 0 && unknown.stage.id < 0)
    }

    @Test
    func ambiguousIDsNeverChooseAnArbitraryRecord() throws {
        let api = try fixture(
            events: eventJSON + "," + eventJSON + #",{"id":102},{"id":0},{"id":-1}"#)
        let data = try convert(api)
        #expect(data.events.map(\.id) == [102])
        #expect(data.omittedRecordCount == 4)
    }

    @Test
    func invalidStartUsesOnlyValidatedLegacyFieldsAndRetainsUnplacedEvents() throws {
        let brokenStart = eventJSON.replacingOccurrences(of: "Europe/Berlin", with: "Not/AZone")
        let validFallback = try #require(convert(fixture(events: brokenStart)).events.first)
        #expect(validFallback.startDate == TestFixtures.date(dayInJuly: 4, hour: 1, minute: 30))
        let unknownTime = try #require(
            convert(
                fixture(
                    events:
                        brokenStart
                        .replacingOccurrences(of: "\"time\":\"01:30\"", with: "\"time\":\"TBA\""))
            ).events.first)
        #expect(unknownTime.startDate == nil)
        #expect(unknownTime.knownDate != nil && unknownTime.festivalDay == 4)
        let unknownDate = try #require(
            convert(
                fixture(
                    events:
                        brokenStart
                        .replacingOccurrences(
                            of: "04.07.\(FestivalConfiguration.year)",
                            with: "31.02.\(FestivalConfiguration.year)"
                        )
                        .replacingOccurrences(of: "\"time\":\"01:30\"", with: "\"time\":\"25:90\""))
            ).events.first)
        #expect(unknownDate.startDate == nil && unknownDate.knownDate == nil)
    }

    @Test
    func wrongFestivalYearNeverBecomesCurrentByUsingLegacyFields() throws {
        let wrongYear = eventJSON.replacingOccurrences(
            of: "\(FestivalConfiguration.year)-07", with: "\(FestivalConfiguration.year - 1)-07")
        let event = try #require(convert(fixture(events: wrongYear)).events.first)
        #expect(event.startDate == nil && event.knownDate == nil)
    }

    @Test(arguments: [
        "2026-02-30 12:00:00.000000", "2026-07-04 25:00:00.000000", "TBA", "2026-07-04 12:00:00",
    ])
    func invalidAPITimestampsAreRejected(value: String) {
        #expect(APITime(date: value, timezoneType: 3, timezone: "Europe/Berlin").getDate() == nil)
    }

    @Test(arguments: [
        ("&#38;", "&"), ("&#x1F3B5;", "🎵"), ("&#xD800;", "&#xD800;"),
        ("&#999999999999999999999;", "&#999999999999999999999;"), ("&nbsp;<br>", "&nbsp;<br>"),
    ])
    func numericHTMLContractIsDeliberatelyLimited(input: String, expected: String) {
        let item = APINewsItem(
            id: 1, title: input, language: "en", teaser: input, text: input,
            time: TestFixtures.apiNewsItem(id: 1, language: "en").time)
        let news = convertAPINewsItemToNewsItem(apiNewsItem: item)
        #expect(news.shortDescription == expected)
        #expect(news.longDescription == expected)
        #expect(news.content == expected)
    }

    @Test
    func bundledProductionDataRetainsIDsAndRelations() throws {
        let url = try #require(
            Bundle.main.url(
                forResource: "\(FestivalConfiguration.year)_rudolstadt_data", withExtension: "json")
        )
        let api = try TestFixtures.sourcePayload(Data(contentsOf: url))
        let data = try convert(api)
        #expect(api.omittedRecordCount == 0 && data.omittedRecordCount == 0)
        #expect(!data.events.isEmpty)
        #expect(Set(data.events.map(\.id)) == Set(try TestFixtures.sourceRecords(api, "events").compactMap { $0["id"] as? Int }))
        #expect(data.events.count == (try TestFixtures.sourceRecords(api, "events").count))
        #expect(data.events.allSatisfy {
                $0.startDate != nil && $0.artist.isMetadataAvailable && $0.stage.isMetadataAvailable
            })
        // The bundled stage 26 has no coordinates. Its two events must remain in the program.
        #expect(data.events.filter { !$0.hasCompleteMetadata }.map(\.id).sorted() == [415, 416])
        #expect(
            data.events.allSatisfy { event in
                data.artists.contains { $0.id == event.artist.id }
                    && data.stages.contains { $0.id == event.stage.id }
            })
        let fallback = try #require(data.stages.first { $0.id == 44 })
        #expect(fallback.area?.id == 0)
        #expect(fallback.area?.germanName == "Sonstige Orte")
        #expect(fallback.area?.englishName == "Other locations")
    }

    @Test @MainActor
    func placeholdersCannotOverwritePersonalState() throws {
        let event = try #require(convert(fixture(events: eventJSON)).events.first)
        let profile = TestFixtures.festivalProfileStore()
        profile.setArtistRating(for: event.artist, rating: 3)
        profile.setArtistNote(for: event.artist, note: "Keep this")
        profile.toggleSavedEvent(event)
        let missing = try #require(
            convert(fixture(events: eventJSON, artists: "", stages: "")).events.first)
        profile.setArtistRating(for: missing.artist, rating: 0)
        profile.setArtistNote(for: missing.artist, note: "")
        #expect(profile.rating(for: 11) == 3)
        #expect(profile.noteText(for: missing.artist) == "Keep this")
        #expect(profile.isEventSaved(missing.id))
        let restored = try #require(convert(fixture(events: eventJSON)).events.first)
        #expect(profile.isEventSaved(restored.id))
        #expect(profile.rating(for: restored.artist.id) == 3)
    }

    @Test
    func incompleteEventsNeverBecomeAutomaticRecommendationsOrTimedConflicts() throws {
        let complete = try #require(convert(fixture(events: eventJSON)).events.first)
        let missing = try #require(
            convert(fixture(events: eventJSON, artists: "", stages: "")).events.first)
        let unplaced = Event(
            id: 102, startDate: nil, knownDate: nil, stage: complete.stage, artist: complete.artist,
            tag: nil)
        let data = TestFixtures.festivalData(events: [missing, unplaced])
        let recommendations = RecommendationService().buildSnapshot(
            data: data, savedEventIds: [],
            ratings: ["11": 3], now: TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0))
        #expect(recommendations.recommendedEventIds.isEmpty)
        #expect(recommendations.estimatedEventDurations[unplaced.id] == nil)
        let evaluator = ScheduleTransitionEvaluator(
            transferEstimator: StageTransferEstimator(stages: data.stages, matrix: .empty))
        let assessment = evaluator.assess(
            first: unplaced, firstDurationMinutes: 60,
            second: complete, secondDurationMinutes: 60, policy: .savedEventWarning)
        #expect(assessment.status == .unknown && assessment.timeOverlapMinutes == 0)
        #expect(evaluator.transferEstimator.estimate(from: missing.stage, to: missing.stage) == nil)
    }
}

extension FestivalDataContractTests {
    @Test(arguments: [("00:00", 3), ("04:59", 3), ("05:00", 4)])
    func festivalDayBoundaryUsesBerlin(time: String, expectedDay: Int) throws {
        let event = try #require(
            convert(
                fixture(
                    events:
                        eventJSON
                        .replacingOccurrences(of: "01:30", with: time))
            ).events.first)
        #expect(event.festivalDay == expectedDay)
    }

    @Test
    func timestampMicrosecondsAreRetained() throws {
        let base = try #require(
            APITime(date: "2026-07-04 01:30:00.000000", timezoneType: 3, timezone: "Europe/Berlin")
                .getDate())
        let precise = try #require(
            APITime(date: "2026-07-04 01:30:00.123456", timezoneType: 3, timezone: "Europe/Berlin")
                .getDate())
        #expect(abs(precise.timeIntervalSince(base) - 0.123456) < 0.000001)
    }

    @Test
    func missingOptionalFieldsAndTagReferencesKeepKnownInformation() throws {
        let api = try fixture(
            events: eventJSON.replacingOccurrences(of: "[33]", with: "[999]"),
            artists: #"{"id":11,"name":"Known artist","category":"concert","hide_artist":true}"#,
            stages: #"{"id":22,"title":"Known stage","category":"cityticket"}"#)
        let event = try #require(try convert(api).events.first)
        #expect(event.artist.isMetadataAvailable && event.artist.hiddenFromArtistList)
        #expect(event.artist.name == "Known artist")
        #expect(event.stage.localizedName == "Known stage")
        #expect(event.tag == nil && !event.stage.hasLocation)
        #expect(!event.hasCompleteMetadata)
        let cached = try KotlinCore.bridge.decodeRudolstadtPayload(sourceJSON: api.sourceJSON)
        #expect(try TestFixtures.sourceRecords(cached, "stages").first?["lat"] == nil)
    }

    @Test
    func unplacedEventsStayReachableAcrossDayFiltersAndSavedViews() throws {
        let scheduled = try #require(convert(fixture(events: eventJSON)).events.first)
        let day = try #require(scheduled.knownDate)
        let unknownTime = Event(
            id: 102, startDate: nil, knownDate: day,
            stage: scheduled.stage, artist: scheduled.artist, tag: nil)
        let unknownDate = Event(
            id: 103, startDate: nil, knownDate: nil,
            stage: scheduled.stage, artist: scheduled.artist, tag: nil)
        let events = [scheduled, unknownTime, unknownDate]
        let today = ScheduleEventSections(events: events, selectedDay: 4)
        #expect(today.scheduled.isEmpty)
        #expect(today.unknownTime.map(\.id) == [102])
        #expect(today.unknownDate.map(\.id) == [103])
        let otherDay = ScheduleEventSections(events: events, selectedDay: 5)
        #expect(otherDay.unknownTime.isEmpty)
        #expect(otherDay.unknownDate.map(\.id) == [103])
        let presenter = SchedulePresenter(
            festivalData: TestFixtures.festivalData(events: events),
            recommendationState: TestFixtures.recommendationState([]), scheduleFilterType: .saved,
            profileState: TestFixtures.profileState(saved: [102, 103], positive: []))
        #expect(presenter.availableEventDays == [3, 4])
        guard case .success(let saved) = presenter.shownEvents else {
            Issue.record("Saved events must remain available"); return
        }
        #expect(Set(saved.map(\.id)) == [102, 103])
    }
}

extension FestivalDataContractTests {
    @Test
    func watchRetainsUnplacedBookmarksWithoutInventingANextEvent() throws {
        let known = try #require(convert(fixture(events: eventJSON)).events.first)
        let preciseStart = try #require(known.startDate).addingTimeInterval(12.123456)
        let precise = Event(
            id: known.id, startDate: preciseStart, knownDate: nil,
            stage: known.stage, artist: known.artist, tag: nil)
        let unplaced = Event(
            id: 102, startDate: nil, knownDate: known.knownDate,
            stage: known.stage, artist: known.artist, tag: nil)
        let evaluator = ScheduleTransitionEvaluator(
            transferEstimator:
                StageTransferEstimator(stages: [known.stage], matrix: .empty))
        let now = TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        let result = WatchSnapshotBuilder().build(
            WatchSnapshotBuildInput(
                festivalYear: FestivalConfiguration.year, revision: 1, generatedAt: now,
                environment: .production,
                freshness: WatchSnapshotFreshness(
                    festivalDataSource: .remote, festivalDataUpdatedAt: now,
                    refreshCheckedAt: now, profileCloudRefreshedAt: now,
                    recommendationsGeneratedAt: nil),
                events: [precise, unplaced], savedEventIDs: [precise.id, unplaced.id],
                ratingsByArtistID: [:],
                estimatedDurationsByEventID: [:],
                recommendations: WatchRecommendationSnapshot(
                    state: .unavailable, generatedAt: nil, orderedEventIDs: []),
                friends: WatchFriendSnapshot(state: .unavailable, updatedAt: nil),
                friendProfiles: [],
                transitionEvaluator: evaluator))
        #expect(result.envelope.payload.events.first?.startDate == preciseStart)
        #expect(result.envelope.payload.unplacedSavedEvents?.map(\.id) == [102])
        #expect(result.envelope.payload.hasIncompleteProgram == true)
        let state = WatchSnapshotState(
            snapshot: result.envelope, availability: .available, importDiagnostic: nil)
        #expect(
            WatchNextEventTimelineProjector().entry(for: state, at: now).content == .planUnavailable
        )
        #expect(
            WatchDayPlanProjector().project(
                state: state,
                at: now.addingTimeInterval(3 * 24 * 60 * 60)
            ).content == .programUnavailable)
        let encoded = try WatchSnapshotCodec().encode(result.envelope)
        let decoded = try WatchSnapshotCodec().decode(encoded)
        #expect(decoded.payload.unplacedSavedEvents?.map(\.id) == [102])
        #expect(
            WatchSnapshotValidator(expectedFestivalYear: FestivalConfiguration.year)
                .validate(encoded, currentRevision: nil) == .accepted(decoded))
    }
}

struct CoreBoundaryContractTests {
    @Test
    func malformedSourceThrowsAcrossTheKotlinBoundary() {
        #expect(throws: (any Error).self) {
            _ = try KotlinCore.bridge.convertRudolstadt(sourceJSON: "{", extraJSON: "{}", year: 2026, fold: KotlinCore.foldProgramText)
        }
    }

    @Test
    func malformedProgramCacheThrowsAcrossTheKotlinBoundary() {
        #expect(throws: (any Error).self) {
            _ = try KotlinCore.bridge.decodeProgram(cacheJSON: "{\"artists\":null}")
        }
    }

    @Test
    func invalidDayAssignmentThrowsInsteadOfEscapingToSwift() {
        #expect(throws: (any Error).self) {
            _ = try KotlinCore.bridge.assignDays(events: [], zone: "Invalid/Zone", boundaryHour: 5, earliestDate: nil)
        }
    }

    @Test
    func typedBridgeRetainsLargeEntityIDs() {
        let ids = KotlinCore.ids([136107827955517])
        #expect(ids.first?.int64Value == 136107827955517)
    }
}


extension CoreBoundaryContractTests {
    @Test
    func typedDurationAndDayEntriesSurviveTheObjectiveCBridge() throws {
        let id = 136107827955517
        let event = TestFixtures.event(id: id, dayInJuly: 3, timeAsString: "20:00",
            stage: TestFixtures.stage(id: 1), artist: TestFixtures.artist(id: 2))
        let resolved = FestivalDurationResolver.resolve([event])
        #expect(resolved.first?.id == id)
        #expect(resolved.first?.duration?.minutes == 60)
        let assignment = try KotlinCore.bridge.assignDays(
            events: [CoreEvent(event).core],
            zone: "Europe/Berlin", boundaryHour: 5, earliestDate: nil)
        #expect(assignment.eventDays.first { $0.eventID == id }?.dayID == "2026-07-03")
    }
}


extension CoreBoundaryContractTests {
    @Test
    func viewsKeepSharedKotlinObjectsAndEnrichmentCannotMutateTheSource() throws {
        let program = try convertFestivalSourceToProgram(
            apiData: TestFixtures.apiFestivalData(artistID: 136107827955517), extraData: .empty())
        let data = try program.native()
        let artist = try #require(data.artists.first)
        #expect(artist === program.artists.first)
        #expect(artist.id == 136107827955517)
        let enriched = artist.replacing(defaultContentLanguage: LanguageTag("de"))
        #expect(enriched !== artist)
        #expect(artist.defaultContentLanguage == nil)
        #expect(enriched.defaultContentLanguage == LanguageTag("de"))
        let cached = try KotlinCore.bridge.decodeProgram(cacheJSON: KotlinCore.bridge.encodeProgram(program: program))
        #expect(cached.artists.first?.id == artist.id)
        let adapter = FestivalRegistry.rudolstadt(year: 2026, source: FestivalDataProviderStub(),
            archive: false, includesSupplementaryInformation: false)
        let prepared = try adapter.prepare(data, source: .cache)
        #expect(prepared.artists.first?.content === artist.content)
    }
}
