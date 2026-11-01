import Foundation

/// An immutable, bundled copy of an official festival export or app release.
/// It never reads or writes the active program's cache or curated resources.
struct RudolstadtArchiveDataProvider: FestivalDataProviding {
    let year: Int
    private let bundle: Bundle

    init(year: Int, bundle: Bundle = .main) {
        self.year = year
        self.bundle = bundle
    }

    var cacheModificationDate: Date? { nil }
    var isCacheStale: Bool { false }
    func loadCachedData() -> FileLoadingResult<FestivalData> { .notFound }
    func deleteCache() -> Bool { true }
    func loadBrowseTaxonomy() -> [BrowseTaxonomyEntry] { [] }
    func loadArtistLinks() -> [String: ArtistLinks] { [:] }

    func loadBundledData() -> FileLoadingResult<FestivalData> {
        guard let url = snapshotURL else { return .notFound }
        do {
            return .loaded(try Self.decode(Data(contentsOf: url), year: year))
        } catch {
            return .unparsable
        }
    }

    func refresh() async throws -> FestivalData {
        try Task.checkCancellation()
        guard let url = snapshotURL else { throw ArchiveError.unavailable }
        let data = try Self.decode(Data(contentsOf: url), year: year)
        try Task.checkCancellation()
        return data
    }

    private var snapshotURL: URL? {
        bundle.url(forResource: "\(year)_archive", withExtension: "json")
            ?? bundle.url(forResource: "\(year)_archive", withExtension: "json", subdirectory: "FestivalBackup")
    }

    static func decode(_ data: Data, year: Int) throws -> FestivalData {
        try JSONDecoder().decode(ArchiveSnapshot.self, from: data).festivalData(expectedYear: year)
    }

    enum ArchiveError: Error {
        case unavailable, unsupportedSchema, wrongYear, invalidData
    }
}

private struct ArchiveSnapshot: Decodable {
    struct LocalizedRecord: Decodable {
        let id: Int
        let de: String
        let en: String
    }

    struct ArtistRecord: Decodable {
        let id: Int
        let type: Int
        let number: Int
        let name: String
        let countries: String
        let website: String
        let facebook: String
        let youtube: String
        let image: String
        let thumbURL: String?
        let fullURL: String?
        let hidden: Bool?
        let instagram: String?
        let de: String
        let en: String
    }

    struct StageRecord: Decodable {
        let id: Int
        let de: String
        let en: String
        let descriptionDE: String
        let descriptionEN: String
        let number: Int?
        let latitude: Double?
        let longitude: Double?
        let area: Int
        let type: Int?
    }

    struct EventRecord: Decodable {
        let id: Int
        let day: Int
        let time: String
        let stage: Int
        let artist: Int
        let tags: [Int]
    }

    let schemaVersion: Int
    let year: Int
    let artists: [ArtistRecord]
    let areas: [LocalizedRecord]
    let stages: [StageRecord]
    let events: [EventRecord]
    let tags: [LocalizedRecord]

    func festivalData(expectedYear: Int) throws -> FestivalData {
        guard schemaVersion == 1 else { throw RudolstadtArchiveDataProvider.ArchiveError.unsupportedSchema }
        guard year == expectedYear else { throw RudolstadtArchiveDataProvider.ArchiveError.wrongYear }
        guard !self.artists.isEmpty, !self.events.isEmpty else {
            throw RudolstadtArchiveDataProvider.ArchiveError.invalidData
        }
        let areas = self.areas.map {
            Area(id: $0.id, germanName: decoded($0.de), englishName: decoded($0.en))
        }
        let areasByID = try unique(areas, id: \.id)
        let tags = self.tags.map {
            Tag(id: $0.id, germanName: decoded($0.de), englishName: decoded($0.en))
        }
        _ = try unique(self.tags, id: \.id)
        let tagsByID = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
        let artists = try self.artists.map { record -> Artist in
            guard let type = ArtistType(rawValue: record.type), !record.name.isEmpty else {
                throw RudolstadtArchiveDataProvider.ArchiveError.invalidData
            }
            let countries = decoded(record.countries)
            return Artist(
                id: record.id, hiddenFromArtistList: record.hidden ?? false, artistType: type,
                name: decoded(record.name), countries: countries,
                countryCodes: parseArtistCountryCodes(countries), url: optional(record.website),
                facebookID: optional(record.facebook), youtubeID: optional(record.youtube), instagram: record.instagram.flatMap(optional),
                descriptionGerman: optional(decoded(record.de)), descriptionEnglish: optional(decoded(record.en)),
                thumbImageUrlString: rudolstadtArtistImageURL(try record.thumbURL.map(assetURL) ?? imageURL(record.image, kind: "thumbs")),
                fullImageUrlString: rudolstadtArtistImageURL(try record.fullURL.map(assetURL) ?? imageURL(record.image, kind: "full")), ai: nil
            )
        }.sorted {
            normalize(string: $0.name, locale: Locale(identifier: "en_US_POSIX"))
                < normalize(string: $1.name, locale: Locale(identifier: "en_US_POSIX"))
        }
        let artistsByID = try unique(artists, id: \.id)
        let stages = try self.stages.map { record -> Stage in
            guard let area = areasByID[record.area] else {
                throw RudolstadtArchiveDataProvider.ArchiveError.invalidData
            }
            return Stage(
                id: record.id, germanName: decoded(record.de), englishName: decoded(record.en),
                germanDescription: optional(decoded(record.descriptionDE)),
                englishDescription: optional(decoded(record.descriptionEN)), stageNumber: record.number,
                latitude: record.latitude ?? .nan, longitude: record.longitude ?? .nan,
                area: area, stageType: record.type.flatMap(StageType.init(rawValue:)) ?? .unknown
            )
        }
        let stagesByID = Dictionary(uniqueKeysWithValues: stages.map { ($0.id, $0) })
        _ = try unique(self.events, id: \.id)
        let events = try self.events.map { record -> Event in
            let day = String(format: "%04d-07-%02d", year, record.day)
            guard let date = FestivalDateUtilities.parse(day, format: "yyyy-MM-dd"),
                  let start = FestivalDateUtilities.parse(day + " " + record.time, format: "yyyy-MM-dd HH:mm"),
                  let stage = stagesByID[.numeric(record.stage)], let artist = artistsByID[record.artist],
                  record.tags.allSatisfy({ tagsByID[String($0)] != nil })
            else { throw RudolstadtArchiveDataProvider.ArchiveError.invalidData }
            return Event(
                id: record.id, startDate: start, knownDate: date, stage: stage, artist: artist,
                tags: record.tags.compactMap { tagsByID[String($0)] }
            )
        }.sorted(by: Event.precedes)
        return FestivalData(
            artists: artists, areas: areas, stages: stages, events: events, festivalYear: year,
            identity: FestivalIdentity(festivalID: "rudolstadt", editionID: String(year))
        )
    }

    private func imageURL(_ name: String, kind: String) throws -> String {
        guard !name.isEmpty else { return "" }
        guard let base = URL(string: "https://www.rudolstadt-festival.de/data/\(year)/images/\(kind)/") else {
            throw RudolstadtArchiveDataProvider.ArchiveError.invalidData
        }
        return base.appendingPathComponent(name).absoluteString
    }

    private func assetURL(_ path: String) throws -> String {
        guard !path.isEmpty else { return "" }
        guard path.hasPrefix("/assets/images/"),
              let url = URL(string: "https://www.rudolstadt-festival.de" + path) else {
            throw RudolstadtArchiveDataProvider.ArchiveError.invalidData
        }
        return url.absoluteString
    }

    private func decoded(_ value: String) -> String { value.decodingHTMLCharacterReferences() }
    private func optional(_ value: String) -> String? { value.isEmpty ? nil : value }

    private func unique<Value>(_ values: [Value], id: KeyPath<Value, Int>) throws -> [Int: Value] {
        var result: [Int: Value] = [:]
        for value in values {
            let key = value[keyPath: id]
            guard key > 0, result.updateValue(value, forKey: key) == nil else {
                throw RudolstadtArchiveDataProvider.ArchiveError.invalidData
            }
        }
        return result
    }
}
