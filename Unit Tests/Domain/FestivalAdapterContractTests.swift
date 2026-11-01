import Foundation
import Testing
@testable import Rudolstadt

@MainActor
struct FestivalAdapterContractTests {
    @Test
    func ludwigsburgOffersBothMapsWithoutAreasOrAutomaticPlanning() async throws {
        let adapter = try #require(FestivalRegistry.catalog.adapter(for: FestivalEdition.ludwigsburg2026.identity))
        let snapshot = try #require(try await adapter.loadBundledProgram())
        #expect(snapshot.artists.count == 37)
        #expect(snapshot.events.count == 219)
        #expect(snapshot.stages.count == 49)
        #expect(!snapshot.features.areas.isSupported)
        #expect(!snapshot.features.automaticPlanning.isSupported)
        let maps = try #require(snapshot.features.map.value)
        #expect(maps.maps.map(\.id) == ["geographic", "site-plan"])
        let illustratedMap = try #require(maps.maps.first { $0.id == "site-plan" })
        guard case .illustrated(let artwork, let positions) = illustratedMap.content else {
            Issue.record("Expected the illustrated map")
            return
        }
        if case .rasterImage = artwork.format { } else { Issue.record("Expected an unlabelled background image") }
        #expect(artwork.localFileURL.pathExtension == "png")
        #expect(positions.count == 44)
        #expect(positions[.numeric(9)] != nil)
        #expect(snapshot.features.sitePlan.value?.document.localFileURL.pathExtension == "pdf")
        #expect(snapshot.stages.first { $0.id == .numeric(9) }?.reference == "A")
        let details = try #require(snapshot.features.placeDetails.value)
        let stageDescription = try #require(details.details(for: .numeric(9))?.description?.text)
        #expect(stageDescription.text(in: LanguageTag("de"))?.contains("Stimmkarten") == true)
        #expect(stageDescription.text(in: LanguageTag("en"))?.contains("Voting-card") == true)
        #expect(snapshot.events.allSatisfy { $0.duration?.isEstimated == false })
    }

    @Test
    func geographicMapIncludesUnnumberedPlacesAndParkingWithoutInventingMissingCoordinates() throws {
        let located = TestFixtures.stage(id: 101)
        let unlocated = TestFixtures.stage(id: 102, latitude: 0, longitude: 0)
        let raw = TestFixtures.festivalData(events: [
            TestFixtures.event(id: 1, dayInJuly: 3, timeAsString: "12:00", stage: located, artist: TestFixtures.artist(id: 1)),
            TestFixtures.event(id: 2, dayInJuly: 3, timeAsString: "13:00", stage: unlocated, artist: TestFixtures.artist(id: 2))
        ])
        let adapter = FestivalRegistry.rudolstadt(year: 2026, source: FestivalDataProviderStub(), archive: false)
        let snapshot = try adapter.prepare(raw, source: .preview)
        let maps = try #require(snapshot.features.map.value)
        let coordinates = try #require(maps.maps.compactMap { map -> [FestivalPlaceID: FestivalCoordinate]? in
            if case .geographic(let coordinates) = map.content { return coordinates }
            return nil
        }.first)
        #expect(located.displayCode == nil)
        #expect(Set(coordinates.keys) == [.numeric(101), .text("parking-raiffeisen"), .text("parking-correns")])
        #expect(snapshot.stages.contains { $0.id == .numeric(102) })
        for id in [FestivalPlaceID.text("parking-raiffeisen"), .text("parking-correns")] {
            #expect(maps.category(for: id)?.id == "parking")
            #expect(maps.category(for: id)?.systemImageName == "parkingsign.circle")
        }
    }

    @Test
    func disablingPlanningPreservesPublishedTimelineDurations() async throws {
        let settings = UserSettings(userDefaults: TestFixtures.isolatedUserDefaults())
        let store = DataStore(userSettings: settings, edition: .ludwigsburg2026, loadInitialData: false)
        await store.loadOrRefreshFestivalData()
        let before = try #require(store.loadedFestivalData).events.compactMap(\.duration)
        await store.refreshRecommendations()
        let after = try #require(store.loadedFestivalData).events.compactMap(\.duration)
        #expect(before == after)
        #expect(before.count == 219)
        if case .success(let data) = store.festivalData {
            #expect(data.eventDurations.count == 219)
            #expect(data.stages.allSatisfy { $0.area == nil })
        } else { Issue.record("Expected a usable timeline without an optimizer") }
    }

    @Test
    func programSupportsTextPlaceIDsAndIndependentCalendarDays() throws {
        let fixture = try fixture()
        let snapshot = try fixture.snapshot.prepared(using: fixture.metadata)
        let data = snapshot
        #expect(data.events.first?.stage.id == .text("courtyard"))
        #expect(data.events.first?.programDay?.date == FestivalCalendarDate(year: 2027, month: 1, day: 1))
        #expect(data.events.first?.knownDate == fixture.snapshot.events.first?.knownDate)
        #expect(data.stages.first?.area == nil)
        #expect(!snapshot.features.map.isSupported)
        #expect(!snapshot.features.automaticPlanning.isSupported)
    }

    @Test
    func invalidOptionalMapDoesNotMakeProgramUnavailable() throws {
        let fixture = try fixture()
        let map = FestivalMap(id: "broken", title: text("Plan"), content: .geographic(coordinates: [
            .text("courtyard"): FestivalCoordinate(latitude: 200, longitude: 9, isApproximate: false, sourceURL: nil)
        ]))
        let provider = FestivalMapCatalog(maps: [map], defaultMapID: map.id, categories: [], assignments: [:])
        var input = fixture.snapshot
        input.features = FestivalFeatures(map: .available(provider))
        let output = try input.prepared(using: fixture.metadata)
        #expect(output.events.count == 1)
        if case .unavailable = output.features.map { } else { Issue.record("Expected an explicit map failure") }
    }

    @Test
    func catalogRejectsDuplicateRegistrationAndUnknownDefault() throws {
        let value = try fixture()
        let adapter = ContractAdapter(metadata: value.metadata, value: value.snapshot)
        #expect(throws: (any Error).self) {
            try FestivalCatalog(adapters: [adapter, adapter], defaultIdentity: adapter.metadata.identity)
        }
        #expect(throws: (any Error).self) {
            try FestivalCatalog(adapters: [adapter], defaultIdentity: FestivalIdentity(festivalID: "other", editionID: "2027"))
        }
    }

    @Test
    func suppliedDurationWinsAndEstimatesDoNotRequirePlanning() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let stage = Stage(id: .text("stage"), name: text("Stage"), reference: nil)
        let artist = TestFixtures.artist(id: 1)
        let events = [
            Event(id: 1, startDate: start, knownDate: start, stage: stage, artist: artist, durationMinutes: 25),
            Event(id: 2, startDate: start.addingTimeInterval(3600), knownDate: start, stage: stage, artist: artist),
            Event(id: 3, startDate: nil, knownDate: nil, stage: .missing(id: -3), artist: artist)
        ]
        let resolved = FestivalDurationResolver.resolve(events)
        #expect(resolved[0].duration == FestivalEventDuration(minutes: 25, isEstimated: false))
        #expect(resolved[1].duration?.isEstimated == true)
        #expect(resolved[2].duration == nil)
    }

    @Test
    func rejectedIdentityDoesNotReplaceConfirmedProgram() throws {
        let fixture = try fixture()
        let adapter = ContractAdapter(metadata: fixture.metadata, value: fixture.snapshot)
        let store = DataStore(userSettings: UserSettings(userDefaults: TestFixtures.isolatedUserDefaults()),
            festivalAdapter: adapter, loadInitialData: false)
        try store.install(fixture.snapshot)
        var other = fixture.snapshot
        other.identity = FestivalIdentity(festivalID: "other", editionID: "2027")
        #expect(throws: (any Error).self) { try store.install(other) }
        #expect(store.loadedFestivalData?.identity == fixture.metadata.identity)
        #expect(store.festivalProfileStore.userDataPolicy.artistNotes == .readOnly)
    }

    @Test
    func readOnlyNotesPreserveExistingValuesWhileRatingsAndSavedEventsRemainEditable() async throws {
        let fixture = try fixture()
        let defaults = TestFixtures.isolatedUserDefaults()
        let persistence = UserDefaultsFestivalProfilePersistence(userDefaults: defaults,
            festivalYear: 0, namespace: fixture.metadata.identity.storageKey)
        let original = FestivalProfileStore(cloudKitEnabled: false, persistence: persistence)
        let artist = TestFixtures.artist(id: 1)
        original.setArtistNote(for: artist, note: "Existing note")
        await original.flushPendingPersistence()
        let store = DataStore(userSettings: UserSettings(userDefaults: defaults),
            festivalAdapter: ContractAdapter(metadata: fixture.metadata, value: fixture.snapshot), loadInitialData: false)
        try store.install(fixture.snapshot)
        let profile = store.festivalProfileStore
        profile.setArtistNote(forArtistID: 1, note: "Replacement")
        profile.setArtistRating(for: artist, rating: 3)
        if case .success(let data) = store.festivalData, let event = data.events.first {
            profile.toggleSavedEvent(event)
        }
        #expect(profile.artistNotes["1"] == "Existing note")
        #expect(profile.rating(for: 1) == 3)
        #expect(profile.savedEvents == [1])
        await profile.flushPendingPersistence()
        let restored = FestivalProfileStore(cloudKitEnabled: false, persistence: persistence)
        #expect(restored.artistNotes["1"] == "Existing note")
        #expect(restored.savedEvents == [1])
    }

    @Test
    func oldLudwigsburgNamespaceRetainsRatingsNotesAndSavedEvents() async {
        let defaults = TestFixtures.isolatedUserDefaults()
        let identity = FestivalEdition.ludwigsburg2026.identity
        let old = FestivalProfileStore(cloudKitEnabled: false,
            persistence: UserDefaultsFestivalProfilePersistence(userDefaults: defaults,
                festivalYear: 2026, namespace: "ludwigsburg-2026"))
        let artist = TestFixtures.artist(id: 1)
        old.setArtistRating(for: artist, rating: 2)
        old.setArtistNote(for: artist, note: "Old local note")
        old.toggleSavedEvent(TestFixtures.event(id: 99, dayInJuly: 3, timeAsString: "12:00",
            stage: TestFixtures.stage(id: 1), artist: artist))
        await old.flushPendingPersistence()
        let store = DataStore(userSettings: UserSettings(userDefaults: defaults),
            edition: .ludwigsburg2026, loadInitialData: false)
        #expect(store.metadata.identity == identity)
        #expect(store.festivalProfileStore.rating(for: 1) == 2)
        #expect(store.festivalProfileStore.artistNotes["1"] == "Old local note")
        #expect(store.festivalProfileStore.savedEvents == [99])
        store.festivalProfileStore.setArtistNote(forArtistID: 1, note: "Updated")
        await store.festivalProfileStore.flushPendingPersistence()
        let restored = DataStore(userSettings: UserSettings(userDefaults: defaults),
            edition: .ludwigsburg2026, loadInitialData: false)
        #expect(restored.festivalProfileStore.artistNotes["1"] == "Updated")
    }

    @Test
    func localizedContentSupportsArbitraryLanguagesAndRegionalFallback() {
        let content = LocalizedText(values: [LanguageTag("fr"): "Bonjour", LanguageTag("ja"): "こんにちは"])
        #expect(content.resolved(locale: Locale(identifier: "fr_CA")) == "Bonjour")
        #expect(content.resolved(locale: Locale(identifier: "ja_JP")) == "こんにちは")
        #expect(content.resolved(locale: Locale(identifier: "es"), defaultLanguage: LanguageTag("ja")) == "こんにちは")
    }

    @Test
    func genericNewsRetainsTextIDsAndDoesNotShareReadStateAcrossFestivals() async throws {
        let fixture = try fixture()
        let item = FestivalNewsItem(id: "opening", title: text("Actualités"), summary: nil,
            body: FestivalContent(text: text("Bonjour"), format: .plainText), imageURL: nil,
            publishedAt: nil, updatedAt: nil, sourceURL: nil, links: [], relatedDestinations: [])
        let snapshot = FestivalNewsSnapshot(identity: fixture.metadata.identity, items: [item],
            provenance: try #require(fixture.snapshot.provenance))
        let store = NewsStore(feature: .available(ContractNewsProvider(value: snapshot)), identity: fixture.metadata.identity)
        await store.refreshNewsIfNecessary()
        #expect(store.snapshot?.items.first?.id == "opening")
        #expect(!store.usesLegacyPresentation)
        let settings = UserSettings(userDefaults: TestFixtures.isolatedUserDefaults())
        settings.markFestivalNewsRead("opening", identity: fixture.metadata.identity)
        #expect(settings.isFestivalNewsRead("opening", identity: fixture.metadata.identity))
        #expect(!settings.isFestivalNewsRead("opening", identity: FestivalEdition.current.identity))
        #expect(settings.readNews.isEmpty)
    }

    @Test
    func preparingProgramRetainsLocalizedContentTagsAndLinkedArtist() throws {
        let fixture = try fixture()
        var data = fixture.snapshot
        let link = FestivalLink(id: "music", title: text("Musique"),
            destination: try #require(URL(string: "https://example.com/artist")), openingMode: .externalBrowser)
        let summary = ArtistSummary(text: "Résumé", language: LanguageTag("fr"), origin: .editorial, sourceURL: link.destination)
        let artist = Artist(id: 1, name: "Artist", details: ArtistDetails(
            descriptions: FestivalContent(text: text("Description"), format: .plainText),
            thumbnailURL: link.destination, imageURL: link.destination, countryCodes: ["FR"], links: [link],
            countryDescription: text("France"), keywords: [LanguageTag("fr"): ["folk"]], musicPreview: .disabled),
            groupIDs: ["custom": ["folk"]], summaries: [LanguageTag("fr"): summary])
        data.artists = [artist]
        data.events[0].tags = [Tag(id: "opening-workshop", title: text("Atelier"), showsOnTimeline: false)]

        let prepared = try data.prepared(using: fixture.metadata)
        let again = try prepared.prepared(using: fixture.metadata)
        let event = try #require(again.events.first)

        #expect(event.artist.formattedDescription(locale: Locale(identifier: "fr")) == "Description")
        #expect(event.artist.additionalLinks.map(\.destination) == [link.destination])
        #expect(event.artist.summary(locale: Locale(identifier: "fr")) == "Résumé")
        #expect(event.artist.keywordLabels(locale: Locale(identifier: "fr")) == ["folk"])
        #expect(event.artist.groupIDs == ["custom": ["folk"]])
        #expect(event.artist.thumbImageUrl == link.destination)
        #expect(event.tags.map(\.id) == ["opening-workshop"])
        #expect(event.tag?.showsOnTimeline == false)
        #expect(event.programDay?.date == FestivalCalendarDate(year: 2027, month: 1, day: 1))
        #expect(again.festivalYear == 2027)
        #expect(again.provenance == data.provenance)
    }

    @Test
    func sourcePreparationPreservesIncompleteEventsAndEstimatedDurations() throws {
        let artist = TestFixtures.artist(id: 10)
        let stage = TestFixtures.stage(id: 20)
        var estimated = TestFixtures.event(id: 30, dayInJuly: 3, timeAsString: "15:00", stage: stage, artist: artist)
        estimated.resolvedDuration = FestivalEventDuration(minutes: 40, isEstimated: true)
        estimated.tags = [Tag(id: "workshop", title: text("Atelier"))]
        let unknown = Event(id: 31, startDate: nil, knownDate: nil,
                            stage: .missing(id: -31), artist: .missing(id: -31))
        let raw = TestFixtures.festivalData(events: [estimated, unknown])
        let adapter = FestivalRegistry.rudolstadt(year: 2026, source: FestivalDataProviderStub(),
            archive: false, includesSupplementaryInformation: false)

        let data = try adapter.prepare(raw, source: .staleCache)

        #expect(data.events.map(\.id) == [30, 31])
        #expect(data.events[0].duration == FestivalEventDuration(minutes: 40, isEstimated: true))
        #expect(data.events[0].tag?.title.text(in: LanguageTag("fr")) == "Atelier")
        #expect(data.events[1].startDate == nil)
        #expect(data.events[1].knownDate == nil)
        #expect(!data.events[1].artist.isMetadataAvailable)
        #expect(!data.events[1].stage.isMetadataAvailable)
        #expect(data.provenance?.source == .staleCache)
    }

    @Test
    func sourcePreparationRejectsAnotherFestivalEvenInTheSameYear() throws {
        var data = TestFixtures.festivalData(events: [])
        data.identity = FestivalEdition.ludwigsburg2026.identity
        let adapter = FestivalRegistry.rudolstadt(year: 2026, source: FestivalDataProviderStub(), archive: false)
        #expect(throws: FestivalLoadingError.wrongIdentity) { try adapter.prepare(data, source: .cache) }
    }

    @Test
    func installingProgramPublishesDataAndProvenanceTogether() throws {
        let fixture = try fixture()
        let store = DataStore(userSettings: TestFixtures.userSettings(),
            festivalAdapter: ContractAdapter(metadata: fixture.metadata, value: fixture.snapshot), loadInitialData: false)
        var publishedSources = [FestivalDataSource]()
        store.onWatchSnapshotInputsChange = { [weak store] in
            if let source = store?.loadedFestivalData?.provenance?.source { publishedSources.append(source) }
        }

        try store.install(fixture.snapshot)

        #expect(publishedSources == [.preview])
        #expect(store.festivalDataProvenance == store.loadedFestivalData?.provenance)
    }

    @Test
    func deletingCachePreservesTheVisibleProgramsProvenance() async throws {
        let fixture = try fixture()
        var data = fixture.snapshot
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        data.provenance = FestivalDataProvenance(source: .cache, dataUpdatedAt: date, refreshCheckedAt: date)
        let store = DataStore(userSettings: TestFixtures.userSettings(),
            festivalAdapter: ContractAdapter(metadata: fixture.metadata, value: data), loadInitialData: false)
        try store.install(data)
        #expect(store.festivalDataLastDownloadDate == date)

        #expect(await store.deleteCachedFestivalData())

        #expect(store.festivalDataLastDownloadDate == nil)
        #expect(store.festivalDataProvenance == data.provenance)
        #expect(store.loadedFestivalData?.events.map(\.id) == data.events.map(\.id))
    }

    private func fixture() throws -> (metadata: FestivalMetadata, snapshot: FestivalData) {
        let identity = FestivalIdentity(festivalID: "contract-test", editionID: "new-year")
        let calendar = Calendar(identifier: .gregorian)
        let localDate = FestivalCalendarDate(year: 2027, month: 1, day: 1)
        let anchor = try #require(localDate.date(in: calendar))
        let day = FestivalDay(id: "opening", date: localDate, title: nil,
            interval: DateInterval(start: anchor, duration: 26 * 3600))
        let start = anchor.addingTimeInterval(25 * 3600)
        let metadata = FestivalMetadata(identity: identity, name: text("Test"), editionLabel: text("Winter"),
            editionKind: .regular, dateRange: nil, timeZone: calendar.timeZone, defaultContentLanguage: LanguageTag("fr"),
            officialLinks: [], presentation: FestivalPresentation(logoURL: nil, accentColorHex: nil), notices: [],
            userDataPolicy: FestivalUserDataPolicy(savedEvents: .editable, artistRatings: .editable, artistNotes: .readOnly))
        let artist = TestFixtures.artist(id: 1, name: "Artist")
        let stage = Stage(id: .text("courtyard"), name: text("Cour"), reference: "C")
        var event = Event(id: 1, startDate: start, knownDate: start, stage: stage, artist: artist, durationMinutes: 25,
                          timeZone: calendar.timeZone)
        event.programDay = day
        var data = FestivalData(artists: [artist], areas: [], stages: [stage], events: [event])
        data.days = [day]
        data.identity = identity
        data.metadata = metadata
        data.provenance = FestivalDataProvenance(source: .preview, dataUpdatedAt: nil, refreshCheckedAt: nil)
        return (metadata, data)
    }

    private func text(_ value: String) -> LocalizedText { LocalizedText(values: [LanguageTag("fr"): value]) }
}

private struct ContractAdapter: FestivalAdapter {
    let metadata: FestivalMetadata
    let value: FestivalData
    var loadingStrategy: FestivalLoadingStrategy { .bundledOnly }
    var services: FestivalServices { FestivalServices() }
    func loadCachedProgram() async throws -> FestivalData? { nil }
    func loadBundledProgram() async throws -> FestivalData? { value }
    func refresh() async throws -> FestivalData { value }
    func deleteCache() async throws { }
}

private struct ContractNewsProvider: FestivalNewsProviding {
    let value: FestivalNewsSnapshot
    func loadCachedNews() async throws -> FestivalNewsSnapshot? { nil }
    func loadBundledNews() async throws -> FestivalNewsSnapshot? { nil }
    func refreshNews() async throws -> FestivalNewsSnapshot { value }
    func deleteCache() async throws { }
}
