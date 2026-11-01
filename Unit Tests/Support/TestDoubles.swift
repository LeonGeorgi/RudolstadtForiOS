import Foundation
@testable import Rudolstadt

final class FestivalProfilePersistenceSpy: FestivalProfilePersisting, @unchecked Sendable {
    private let lock = NSLock()
    private let loadedCache: FestivalProfileCache?
    private let legacyProfile: CachedOwnerFestivalProfile
    private var persistedCachesStorage: [FestivalProfileCache] = []

    init(
        loadedCache: FestivalProfileCache? = nil,
        legacyProfile: CachedOwnerFestivalProfile
    ) {
        self.loadedCache = loadedCache
        self.legacyProfile = legacyProfile
    }

    func loadCache() -> FestivalProfileCache? {
        loadedCache
    }

    func loadLegacyOwnerProfile() -> CachedOwnerFestivalProfile {
        legacyProfile
    }

    func persist(_ cache: FestivalProfileCache) {
        lock.lock()
        persistedCachesStorage.append(cache)
        lock.unlock()
    }

    var persistedCaches: [FestivalProfileCache] {
        lock.lock()
        defer { lock.unlock() }
        return persistedCachesStorage
    }
}

actor HTTPClientStub: HTTPClient {
    typealias Handler = @Sendable (URL) async throws -> HTTPResponse

    private let handler: Handler
    private(set) var requestedURLs: [URL] = []

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func data(from url: URL) async throws -> HTTPResponse {
        requestedURLs.append(url)
        return try await handler(url)
    }
}

final class FestivalDataFetcherStub: @unchecked Sendable, FestivalDataFetching {
    private let lock = NSLock()
    private let result: Result<APIRudolstadtData, Error>
    private var storedFetchCallCount = 0

    var fetchCallCount: Int {
        lock.withLock { storedFetchCallCount }
    }

    init(data: APIRudolstadtData) {
        result = .success(data)
    }

    init(error: Error) {
        result = .failure(error)
    }

    func fetchFestivalData() async throws -> APIRudolstadtData {
        lock.withLock {
            storedFetchCallCount += 1
        }
        return try result.get()
    }
}

final class FestivalDataCacheStub: @unchecked Sendable, FestivalDataCaching,
    BundledNewsLoading
{
    private let lock = NSLock()
    private var loadResult: FileLoadingResult<FestivalData>
    private let bundledFestivalResult: FileLoadingResult<FestivalData>
    private let bundledNewsResult: FileLoadingResult<[NewsItem]>
    private let storeResult: Bool
    private let modificationDate: Date?
    private var storedLoadCallCount = 0
    private var storedStoreCallCount = 0
    private var storedBundledFestivalLoadCallCount = 0

    var loadCallCount: Int {
        lock.withLock { storedLoadCallCount }
    }

    var storeCallCount: Int {
        lock.withLock { storedStoreCallCount }
    }

    var bundledFestivalLoadCallCount: Int {
        lock.withLock { storedBundledFestivalLoadCallCount }
    }

    init(
        loadResult: FileLoadingResult<FestivalData> = .notFound,
        bundledFestivalResult: FileLoadingResult<FestivalData> = .notFound,
        bundledNewsResult: FileLoadingResult<[NewsItem]> = .notFound,
        storeResult: Bool = true,
        modificationDate: Date? = nil
    ) {
        self.loadResult = loadResult
        self.bundledFestivalResult = bundledFestivalResult
        self.bundledNewsResult = bundledNewsResult
        self.storeResult = storeResult
        self.modificationDate = modificationDate
    }

    func loadFestivalDataFromFile(
        extraData: ExtraDataCollection
    ) -> FileLoadingResult<FestivalData> {
        lock.withLock {
            storedLoadCallCount += 1
            return loadResult
        }
    }

    func setLoadResult(_ result: FileLoadingResult<FestivalData>) {
        lock.withLock { loadResult = result }
    }

    func loadBundledFestivalDataBackup(
        extraData: ExtraDataCollection
    ) -> FileLoadingResult<FestivalData> {
        lock.withLock {
            storedBundledFestivalLoadCallCount += 1
        }
        return bundledFestivalResult
    }

    func storeAPIRudolstadtDataToFile(
        data: APIRudolstadtData,
        fileName: String
    ) -> Bool {
        lock.withLock {
            storedStoreCallCount += 1
        }
        return storeResult
    }

    func deleteCachedFestivalData() -> Bool {
        true
    }

    func cachedFestivalDataModificationDate() -> Date? {
        modificationDate
    }

    func isFileStale(fileName: String) -> Bool {
        false
    }

    func loadBundledNewsBackup() -> FileLoadingResult<[NewsItem]> {
        bundledNewsResult
    }
}

actor ControlledFestivalDataFetcher: FestivalDataFetching {
    private var continuations: [CheckedContinuation<APIRudolstadtData, Error>] = []

    var fetchCallCount: Int {
        continuations.count
    }

    func fetchFestivalData() async throws -> APIRudolstadtData {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func resumeFetch(at index: Int, with data: APIRudolstadtData) {
        continuations[index].resume(returning: data)
    }
}

final class FestivalDataProviderStub: FestivalDataProviding, @unchecked Sendable {
    let cacheModificationDate: Date?
    let isCacheStale: Bool
    private let cachedData: FileLoadingResult<FestivalData>
    private let bundledData: FileLoadingResult<FestivalData>
    private let refreshResult: Result<FestivalData, Error>
    private let taxonomy: [BrowseTaxonomyEntry]
    private let links: [String: ArtistLinks]

    init(
        cachedData: FileLoadingResult<FestivalData> = .notFound,
        bundledData: FileLoadingResult<FestivalData> = .notFound,
        refreshResult: Result<FestivalData, Error> = .failure(URLError(.notConnectedToInternet)),
        cacheModificationDate: Date? = nil,
        isCacheStale: Bool = true,
        taxonomy: [BrowseTaxonomyEntry] = [],
        links: [String: ArtistLinks] = [:]
    ) {
        self.cachedData = cachedData
        self.bundledData = bundledData
        self.refreshResult = refreshResult
        self.cacheModificationDate = cacheModificationDate
        self.isCacheStale = isCacheStale
        self.taxonomy = taxonomy
        self.links = links
    }

    func loadCachedData() -> FileLoadingResult<FestivalData> { cachedData }
    func loadBundledData() -> FileLoadingResult<FestivalData> { bundledData }
    func refresh() async throws -> FestivalData { try refreshResult.get() }
    func deleteCache() -> Bool { true }
    func loadBrowseTaxonomy() -> [BrowseTaxonomyEntry] { taxonomy }
    func loadArtistLinks() -> [String: ArtistLinks] { links }
}

final class NewsAPIStub: NewsFetching {
    var newsToReturn: [APINewsItem]
    var fetchCallCount = 0
    var error: Error?
    var fetchHandler: (() async throws -> [APINewsItem])?

    init(newsToReturn: [APINewsItem] = []) {
        self.newsToReturn = newsToReturn
    }

    func fetchNews() async throws -> [APINewsItem] {
        fetchCallCount += 1
        if let fetchHandler { return try await fetchHandler() }
        if let error { throw error }
        return newsToReturn
    }
}

final class NewsCacheStub: NewsCaching {
    var loadResult: FileLoadingResult<[NewsItem]>
    var bundledResult: FileLoadingResult<[NewsItem]> = .notFound
    var storeSucceeds = true
    var storeCallCount = 0
    var storedNewsIds: [Int] = []
    var isFileOlderThanReturnValue = true
    var requestedOlderThanDate: Date?

    init(loadResult: FileLoadingResult<[NewsItem]>) {
        self.loadResult = loadResult
    }

    func loadNewsFromFile() -> FileLoadingResult<[NewsItem]> {
        loadResult
    }

    func loadBundledNewsBackup() -> FileLoadingResult<[NewsItem]> {
        bundledResult
    }

    func storeAPINewsToFile(news: [APINewsItem], fileName: String) -> Bool {
        storeCallCount += 1
        storedNewsIds = news.map(\.id)
        return storeSucceeds
    }

    func isFileOlderThan(fileName: String, date: Date?) -> Bool {
        requestedOlderThanDate = date
        return isFileOlderThanReturnValue
    }
}

final class NewsNotifierStub: NewsNotifying {
    var notifiedItemIds: [Int] = []
    var attemptedItemIds: [Int] = []
    var failingIDs: Set<Int> = []
    var notifyHandler: ((NewsItem) async throws -> Void)?

    func notifyUser(of item: NewsItem) async throws {
        attemptedItemIds.append(item.id)
        if let notifyHandler { try await notifyHandler(item) }
        if failingIDs.contains(item.id) { throw URLError(.unknown) }
        notifiedItemIds.append(item.id)
    }
}

final class RecommendationServiceStub: RecommendationProviding {
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
