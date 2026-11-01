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
        do { return .loaded(try Self.decode(Data(contentsOf: url))) } catch { return .unparsable }
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
            ?? bundle.url(
                forResource: "ludwigsburg_2026", withExtension: "json",
                subdirectory: "FestivalBackup")
    }

    static func decode(_ data: Data) throws -> FestivalData {
        let result = try KotlinCore.bridge.convertLudwigsburg(
            sourceJSON: String(decoding: data, as: UTF8.self), fold: KotlinCore.foldProgramText)
        guard let program = result.program else { throw SnapshotError.invalidData }
        guard program.sitePlan != nil else { throw SnapshotError.invalidData }
        return try program.native(festivalID: "ludwigsburg", curated: false)
    }

    enum SnapshotError: Error { case unavailable, invalidData }

}
