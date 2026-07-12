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
    private let loadResult: FileLoadingResult<FestivalData>
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
        }
        return loadResult
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

final class NewsAPIStub: NewsFetching {
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

final class NewsCacheStub: NewsCaching {
    let loadResult: FileLoadingResult<[NewsItem]>
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
        .notFound
    }

    func storeAPINewsToFile(news: [APINewsItem], fileName: String) -> Bool {
        storedNewsIds = news.map(\.id)
        return true
    }

    func isFileOlderThan(fileName: String, date: Date?) -> Bool {
        requestedOlderThanDate = date
        return isFileOlderThanReturnValue
    }
}

final class NewsNotifierStub: NewsNotifying {
    var notifiedItemIds: [Int] = []

    func notifyUser(of item: NewsItem) async throws {
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
