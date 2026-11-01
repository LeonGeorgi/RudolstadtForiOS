import Foundation

/// Experimental, immutable snapshot. It owns no Rudolstadt cache or curated data.
struct LudwigsburgFestivalDataProvider: FestivalDataProviding {
    private let bundle: Bundle

    init(bundle: Bundle = .main) { self.bundle = bundle }

    var cacheModificationDate: Date? { nil }
    var isCacheStale: Bool { false }
    func loadCachedData() -> FileLoadingResult<FestivalData> { .notFound }
    func deleteCache() -> Bool { true }
    func loadBrowseTaxonomy() -> [BrowseTaxonomyEntry] { [] }
    func loadArtistLinks() -> [String: ArtistLinks] { [:] }

    func loadBundledData() -> FileLoadingResult<FestivalData> {
        guard let url = snapshotURL else { return .notFound }
        do { return .loaded(try Self.decode(Data(contentsOf: url))) }
        catch { return .unparsable }
    }

    func refresh() async throws -> FestivalData {
        try Task.checkCancellation()
        guard let url = snapshotURL else { throw SnapshotError.unavailable }
        let data = try Self.decode(Data(contentsOf: url))
        try Task.checkCancellation()
        return data
    }

    private var snapshotURL: URL? {
        bundle.url(forResource: "ludwigsburg_2026", withExtension: "json")
            ?? bundle.url(forResource: "ludwigsburg_2026", withExtension: "json", subdirectory: "FestivalBackup")
    }

    static func decode(_ data: Data) throws -> FestivalData {
        try JSONDecoder().decode(Snapshot.self, from: data).festivalData()
    }

    enum SnapshotError: Error { case unavailable, invalidData }

    private struct Snapshot: Decodable {
        struct ArtistRecord: Decodable {
            let id: Int
            let name: String
            let sourceURL: String
            let countries: String
            let countryCodes: [String]
            let descriptionDE: String
            let imageURL: String
            let facebook: String?
            let instagram: String?
            let youtube: String?
        }
        struct StageRecord: Decodable {
            let id: Int
            let name: String
        }
        struct EventRecord: Decodable {
            let id: Int
            let start: String
            let durationMinutes: Int
            let artist: Int
            let stage: Int
        }
        let schemaVersion: Int
        let festivalID: String
        let year: Int
        let timeZone: String
        let omittedRecordCount: Int
        let artists: [ArtistRecord]
        let stages: [StageRecord]
        let events: [EventRecord]
        let sitePlan: FestivalSitePlan

        func festivalData() throws -> FestivalData {
            guard schemaVersion == 1, festivalID == "ludwigsburg-2026", year == 2026,
                  timeZone == "Europe/Berlin", omittedRecordCount >= 0,
                  !artists.isEmpty, !stages.isEmpty, !events.isEmpty,
                  validIDs(artists.map(\.id)), validIDs(stages.map(\.id)), validIDs(events.map(\.id)),
                  artists.allSatisfy({ !$0.name.isEmpty }), stages.allSatisfy({ !$0.name.isEmpty })
            else { throw SnapshotError.invalidData }
            guard sitePlan.isValid(stageIDs: Set(stages.map(\.id))),
                  Set(sitePlan.locations.compactMap(\.stageID)) == Set(stages.map(\.id))
            else { throw SnapshotError.invalidData }

            let area = Area(id: 1, germanName: "Festivalgelände", englishName: "Festival grounds")
            let convertedArtists = artists.map { record in
                Artist(
                    id: record.id, hiddenFromArtistList: false, artistType: .street,
                    name: record.name, countries: record.countries,
                    countryCodes: record.countryCodes, url: record.sourceURL,
                    facebookID: record.facebook, youtubeID: record.youtube, instagram: record.instagram,
                    descriptionGerman: record.descriptionDE.nilIfEmpty(),
                    descriptionEnglish: nil, thumbImageUrlString: record.imageURL,
                    fullImageUrlString: record.imageURL, ai: nil
                )
            }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            let convertedStages = stages.map { record in
                let location = sitePlan.location(forStageID: record.id)
                let coordinate = location?.coordinate
                return Stage(id: record.id, germanName: record.name, englishName: record.name,
                      germanDescription: location?.noteDE, englishDescription: location?.noteEN, stageNumber: nil,
                      latitude: coordinate?.latitude ?? .nan, longitude: coordinate?.longitude ?? .nan,
                      area: area, stageType: .festivalTicket,
                      locationIsApproximate: coordinate?.isApproximate ?? false,
                      stageCode: location?.reference)
            }.sorted(by: Stage.precedes)
            let artistsByID = Dictionary(uniqueKeysWithValues: convertedArtists.map { ($0.id, $0) })
            let stagesByID = Dictionary(uniqueKeysWithValues: convertedStages.map { ($0.id, $0) })
            let convertedEvents = try events.map { record -> Event in
                guard let artist = artistsByID[record.artist], let stage = stagesByID[.numeric(record.stage)],
                      let start = FestivalDateUtilities.parse(record.start, format: "yyyy-MM-dd'T'HH:mm"),
                      FestivalDateUtilities.festivalCalendar.component(.year, from: start) == year,
                      (1...1440).contains(record.durationMinutes)
                else { throw SnapshotError.invalidData }
                return Event(id: record.id, startDate: start, knownDate: start,
                             stage: stage, artist: artist, durationMinutes: record.durationMinutes)
            }.sorted(by: Event.precedes)
            return FestivalData(
                artists: convertedArtists, areas: [area], stages: convertedStages, events: convertedEvents,
                omittedRecordCount: omittedRecordCount, festivalYear: year, sitePlan: sitePlan,
                identity: FestivalIdentity(festivalID: "ludwigsburg", editionID: String(year))
            )
        }

        private func validIDs(_ ids: [Int]) -> Bool {
            ids.allSatisfy { $0 > 0 } && Set(ids).count == ids.count
        }
    }
}
