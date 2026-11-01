import Foundation
import OSLog

/// Supplies a complete program in app models. Each provider owns its cache,
/// backup, conversion, image URLs, and supplementary artist information.
/// News and personal festival profiles have separate lifecycles.
protocol FestivalDataProviding: Sendable {
    var cacheModificationDate: Date? { get }
    var isCacheStale: Bool { get }

    func loadCachedData() -> FileLoadingResult<FestivalData>
    func loadBundledData() -> FileLoadingResult<FestivalData>
    /// Returns downloaded data even if caching fails. Older concurrent refreshes
    /// and cancelled tasks must not overwrite a newer cached result.
    func refresh() async throws -> FestivalData
    func deleteCache() -> Bool
    func loadBrowseTaxonomy() -> [BrowseTaxonomyEntry]
    func loadArtistLinks() -> [String: ArtistLinks]
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
    private var refreshGeneration = 0
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

    nonisolated func loadBundledData() -> FileLoadingResult<FestivalData> {
        cache.loadBundledFestivalDataBackup(extraData: resolvedExtraData())
    }

    func refresh() async throws -> FestivalData {
        refreshGeneration += 1
        let generation = refreshGeneration
        do {
            try Task.checkCancellation()
            let apiData = try await fetcher.fetchFestivalData()
            try Task.checkCancellation()
            let data = convertAPIRudolstadtDataToEntities(
                apiData: apiData,
                extraData: resolvedExtraData()
            )
            try Task.checkCancellation()
            if generation == refreshGeneration {
                let stored = cache.storeAPIRudolstadtDataToFile(
                    data: apiData,
                    fileName: Self.cacheFileName
                )
                if !stored {
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
        switch error {
        case let APIClientError.httpStatus(_, statusCode, _):
            reason = (500...599).contains(statusCode) ? .festivalServerError : .apiNotResponding
            let owner: FestivalDataDownloadFailureOwner
            switch statusCode {
            case 500...599: owner = .festivalSide
            case 400...499: owner = .appSide
            default: owner = .unknown
            }
            failure = FestivalDataDownloadFailure(owner: owner, httpStatusCode: statusCode)
        case APIClientError.invalidResponse, APIClientError.decoding:
            reason = .apiNotResponding
            failure = FestivalDataDownloadFailure(owner: .appSide)
        case is URLError:
            reason = .apiNotResponding
            failure = FestivalDataDownloadFailure(owner: .connection)
        default:
            reason = .apiNotResponding
            failure = FestivalDataDownloadFailure(owner: .unknown)
        }
        return FestivalDataProviderError(
            reason: reason, failure: failure, underlyingError: error
        )
    }
}
