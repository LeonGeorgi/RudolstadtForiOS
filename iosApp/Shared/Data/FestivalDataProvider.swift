import Foundation
import RudolstadtCore
import OSLog

/// Supplies a complete program in app models. Each provider owns its cache,
/// backup, conversion, image URLs, and supplementary artist information.
/// News and personal festival profiles have separate lifecycles.
protocol FestivalDataProviding: Sendable {
    var cacheModificationDate: Date? { get }
    var isCacheStale: Bool { get }

    func loadCachedData() -> FileLoadingResult<FestivalData>
    func loadInitialCachedData() -> FileLoadingResult<FestivalData>
    func loadBundledData() -> FileLoadingResult<FestivalData>
    /// Returns downloaded data even if caching fails. Older concurrent refreshes
    /// and cancelled tasks must not overwrite a newer cached result.
    func refresh() async throws -> FestivalData
    func deleteCache() -> Bool
    func loadBrowseTaxonomy() -> [BrowseTaxonomyEntry]
    func loadArtistLinks() -> [String: ArtistLinks]
}

extension FestivalDataProviding {
    func loadInitialCachedData() -> FileLoadingResult<FestivalData> { .notFound }
}

struct FestivalDataProviderError: LocalizedError {
    let reason: FailureReason
    let failure: FestivalDataDownloadFailure
    let underlyingError: Error

    var errorDescription: String? { underlyingError.localizedDescription }
}

/// Keeps Rudolstadt's wire format and existing cache files behind the provider.
actor RudolstadtFestivalDataProvider: FestivalDataProviding {
    private nonisolated let cache: any FestivalDataCaching
    private let fetcher: any FestivalDataFetching
    private nonisolated let extraData: ExtraDataCollection?
    private let refreshGeneration = RefreshGeneration()
    private static let cacheFileName = "rudolstadt_data.json"

    init(
        fetcher: any FestivalDataFetching = APIClient(),
        cache: any FestivalDataCaching,
        extraData: ExtraDataCollection? = nil
    ) {
        self.fetcher = fetcher
        self.cache = cache
        self.extraData = extraData
    }

    nonisolated var cacheModificationDate: Date? {
        cache.cachedFestivalDataModificationDate()
    }

    nonisolated var isCacheStale: Bool {
        cache.isFileStale(fileName: Self.cacheFileName)
    }

    nonisolated func loadCachedData() -> FileLoadingResult<FestivalData> {
        cache.loadFestivalDataFromFile(extraData: resolvedExtraData())
    }

    nonisolated func loadInitialCachedData() -> FileLoadingResult<FestivalData> {
        cache.loadConvertedFestivalDataFromFile(extraData: resolvedExtraData())
    }

    nonisolated func loadBundledData() -> FileLoadingResult<FestivalData> {
        cache.loadBundledFestivalDataBackup(extraData: resolvedExtraData())
    }

    func refresh() async throws -> FestivalData {
        let generation = refreshGeneration.begin()
        do {
            try Task.checkCancellation()
            let apiData = try await fetcher.fetchFestivalData()
            try Task.checkCancellation()
            let extraData = resolvedExtraData()
            let program = try convertFestivalSourceToProgram(
                apiData: apiData, extraData: extraData)
            let data = try program.native()
            try Task.checkCancellation()
            if refreshGeneration.isCurrent(token: generation) {
                let stored = cache.storeFestivalSourceToFile(
                    data: apiData,
                    fileName: Self.cacheFileName
                )
                if stored {
                    cache.storeConvertedFestivalDataToFile(
                        program: program, source: apiData, extraData: extraData)
                } else {
                    AppLog.data.error("Downloaded festival data but failed to cache it")
                }
            }
            return data
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw Self.providerError(from: error)
        }
    }

    nonisolated func deleteCache() -> Bool {
        cache.deleteCachedFestivalData()
    }

    nonisolated func loadBrowseTaxonomy() -> [BrowseTaxonomyEntry] {
        loadBrowseTaxonomyFromResource(fileName: "browse_taxonomy") ?? []
    }

    nonisolated func loadArtistLinks() -> [String: ArtistLinks] {
        parseArtistLinks()
    }

    private nonisolated func resolvedExtraData() -> ExtraDataCollection {
        extraData ?? loadExtraDataFromResource(fileName: "extra_data") ?? .empty()
    }

    private static func providerError(from error: Error) -> FestivalDataProviderError {
        let reason: FailureReason
        let failure: FestivalDataDownloadFailure
        switch (error as NSError).kotlinException {
        case let httpError as RemoteHttpError:
            let statusCode = Int(httpError.statusCode)
            reason = HttpPolicy.shared.failureOwner(statusCode: Int32(statusCode)) == .server ? .festivalServerError : .apiNotResponding
            let owner: FestivalDataDownloadFailureOwner
            switch HttpPolicy.shared.failureOwner(statusCode: Int32(statusCode)) {
            case .server: owner = .festivalSide
            case .client: owner = .appSide
            default: owner = .unknown
            }
            failure = FestivalDataDownloadFailure(owner: owner, httpStatusCode: statusCode)
        case is RemoteDecodingError:
            reason = .apiNotResponding
            failure = FestivalDataDownloadFailure(owner: .appSide)
        default:
            reason = .apiNotResponding
            failure = FestivalDataDownloadFailure(
                owner: (error as NSError).domain == NSURLErrorDomain ? .connection : .unknown)
        }
        return FestivalDataProviderError(
            reason: reason, failure: failure, underlyingError: error
        )
    }
}
