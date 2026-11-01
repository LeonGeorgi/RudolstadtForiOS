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
            ?? bundle.url(
                forResource: "\(year)_archive", withExtension: "json",
                subdirectory: "FestivalBackup")
    }

    static func decode(_ data: Data, year: Int) throws -> FestivalData {
        let result = try KotlinCore.bridge.convertArchive(
            sourceJSON: String(decoding: data, as: UTF8.self), year: Int32(year),
            fold: KotlinCore.foldProgramText)
        guard let program = result.program else {
            switch result.error {
            case "wrongYear": throw ArchiveError.wrongYear
            case "unsupportedSchema": throw ArchiveError.unsupportedSchema
            default: throw ArchiveError.invalidData
            }
        }
        return try program.native(festivalID: "rudolstadt", curated: false)
    }

    enum ArchiveError: Error {
        case unavailable, unsupportedSchema, wrongYear, invalidData
    }
}
