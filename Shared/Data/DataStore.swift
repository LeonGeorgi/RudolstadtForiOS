import Foundation
import OSLog
import SwiftUI

extension StringProtocol {
    func nilIfEmpty() -> Self? {
        return self.isEmpty ? nil : self
    }
}

@MainActor
final class DataStore: ObservableObject {

    @Published var festivalData: LoadingEntity<FestivalData> = .loading
    @Published var news: LoadingEntity<[NewsItem]> = .loading
    @Published var recommendedEventIDs: LoadingEntity<[Int]> = .loading
    @Published var estimatedEventDurationsByEventID: [Int: Int]? = nil
    @Published var artistLinks: [String: ArtistLinks]? = nil
    @Published var browseTaxonomy: [BrowseTaxonomyEntry] = []
    @Published var festivalDataLastDownloadDate: Date?
    @Published var isUsingBundledFestivalDataBackup = false
    @Published var festivalDataFallbackStatus: FestivalDataFallbackStatus?
    
    var extraData: ExtraDataCollection? = nil
    private var browseTaxonomyByID: [String: BrowseTaxonomyEntry] = [:]

    nonisolated static let year = 2026

    private let festivalDataCache: any FestivalDataCaching
    private let bundledNewsLoader: any BundledNewsLoading
    private let festivalDataFetcher: any FestivalDataFetching
    let newsService: NewsService
    let recommendationService: RecommendationProviding
    let festivalProfileStore: FestivalProfileStore

    private var pendingRecommendationRefreshTask: Task<Void, Never>?
    private var recommendationRefreshGeneration = 0
    private var isRefreshingAppState = false
    private var hasLoadedFestivalContentForAppLaunch = false
    private var lastAppStateRefreshAt: Date?

    init(
        festivalProfileStore: FestivalProfileStore? = nil,
        userSettings: UserSettings? = nil,
        newsService: NewsService? = nil,
        recommendationService: RecommendationProviding? = nil,
        festivalDataFetcher: (any FestivalDataFetching)? = nil,
        festivalDataCache: (any FestivalDataCaching)? = nil,
        bundledNewsLoader: (any BundledNewsLoading)? = nil,
        loadInitialData: Bool = true
    ) {
        let resolvedUserSettings = userSettings ?? UserSettings()
        let resolvedFestivalProfileStore =
            festivalProfileStore ?? FestivalProfileStore()
        let resolvedFestivalDataCache: any FestivalDataCaching
        let resolvedBundledNewsLoader: any BundledNewsLoading
        if let festivalDataCache, let bundledNewsLoader {
            resolvedFestivalDataCache = festivalDataCache
            resolvedBundledNewsLoader = bundledNewsLoader
        } else {
            let defaultDataLoader = Self.makeDefaultDataLoader()
            resolvedFestivalDataCache = festivalDataCache ?? defaultDataLoader
            resolvedBundledNewsLoader = bundledNewsLoader ?? defaultDataLoader
        }
        self.festivalDataCache = resolvedFestivalDataCache
        self.bundledNewsLoader = resolvedBundledNewsLoader
        self.festivalDataFetcher = festivalDataFetcher ?? APIClient()
        self.festivalProfileStore = resolvedFestivalProfileStore
        self.newsService =
            newsService ?? NewsService(userSettings: resolvedUserSettings)
        self.recommendationService = recommendationService ?? RecommendationService()

        guard loadInitialData else {
            return
        }

        if ScreenshotRuntime.isEnabled {
            loadBundledScreenshotData()
            return
        }

        refreshFestivalDataDownloadMetadata()
        loadCachedFestivalDataIfAvailable()
    }

    private static func makeDefaultDataLoader() -> DataLoader {
        do {
            let cacheURL = try FileManager.default.url(
                for: .cachesDirectory,
                in: .allDomainsMask,
                appropriateFor: nil,
                create: false
            )
            return DataLoader(cacheURL: cacheURL)
        } catch {
            preconditionFailure(
                "Could not resolve cache directory: \(error.localizedDescription)"
            )
        }
    }

    private func loadArtistLinksIfNeeded() async {
        guard artistLinks == nil else {
            return
        }

        let links = await loadArtistLinksInBackground()
        artistLinks = links
        AppLog.data.debug("Loaded artist links for \(links.count) artists")
    }

    func refreshRecommendations(now: Date = .now) async {
        guard case .success(let loadedFestivalData) = festivalData else {
            estimatedEventDurationsByEventID = nil
            recommendedEventIDs = .loading
            return
        }

        let savedEventIds = festivalProfileStore.savedEvents
        let ratings = festivalProfileStore.ratings
        let generation = recommendationRefreshGeneration + 1
        recommendationRefreshGeneration = generation

        recommendedEventIDs = .loading
        let snapshot = await buildRecommendationSnapshot(
            festivalData: loadedFestivalData,
            savedEventIds: savedEventIds,
            ratings: ratings,
            now: now
        )
        guard generation == recommendationRefreshGeneration else {
            return
        }
        estimatedEventDurationsByEventID = snapshot.estimatedEventDurations
        recommendedEventIDs = .success(snapshot.recommendedEventIds)
        AppLog.data.debug(
            "Updated recommendations with \(snapshot.recommendedEventIds.count) events"
        )
    }

    func scheduleRecommendationRefresh(now: Date = .now) {
        pendingRecommendationRefreshTask?.cancel()
        pendingRecommendationRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else {
                return
            }
            await self?.refreshRecommendations(now: now)
        }
    }

    func loadOrRefreshFestivalData() async {
        let hadLoadedFestivalDataAtStart: Bool
        if case .success = festivalData {
            hadLoadedFestivalDataAtStart = true
            // nothing to do
        } else {
            hadLoadedFestivalDataAtStart = false
            festivalData = .loading
        }
        loadExtraData()
        let resolvedExtraData = extraData ?? ExtraDataCollection.empty()
        AppLog.data.info("Refreshing festival data")
        let resultFromCache = await loadCachedFestivalData(
            extraData: resolvedExtraData
        )
        switch resultFromCache {
        case .loaded(let cachedData):
            festivalData = .success(cachedData)
            isUsingBundledFestivalDataBackup = false
            festivalDataFallbackStatus = nil
            refreshFestivalDataDownloadMetadata()
            AppLog.data.info(
                "Loaded festival data from cache with \(cachedData.artists.count) artists and \(cachedData.events.count) events"
            )
            return
        case .stale(let cachedData):
            AppLog.data.info(
                "Cached festival data is stale with \(cachedData.artists.count) artists and \(cachedData.events.count) events; downloading update"
            )
        case .notFound:
            AppLog.data.info("No cached festival data found; downloading")
        case .unparsable:
            AppLog.data.error(
                "Cached festival data could not be parsed; downloading fresh data"
            )
        }

        await downloadAndSetFestivalData(
            resultFromCache: resultFromCache,
            preserveCurrentDataOnFailure: hadLoadedFestivalDataAtStart
        )
    }
    
    func loadExtraData() {
        if extraData != nil && !browseTaxonomy.isEmpty {
            return
        }

        self.extraData = loadExtraDataFromResource(fileName: "extra_data")

        let loadedBrowseTaxonomy = loadBrowseTaxonomyFromResource(
            fileName: "browse_taxonomy"
        ) ?? []
        browseTaxonomy = loadedBrowseTaxonomy
        browseTaxonomyByID = Dictionary(
            uniqueKeysWithValues: loadedBrowseTaxonomy.map { entry in
                (entry.id, entry)
            }
        )
    }

    func localizedBrowseGenreLabel(for id: String) -> String {
        browseTaxonomyByID[id]?.localizedLabel ?? id
    }

    func deleteCachedFestivalData() -> Bool {
        let deleted = festivalDataCache.deleteCachedFestivalData()
        if deleted {
            refreshFestivalDataDownloadMetadata()
            AppLog.data.info("Deleted cached festival data")
        }
        return deleted
    }

    var isFestivalDataCacheStale: Bool {
        guard festivalDataLastDownloadDate != nil else {
            return true
        }
        return festivalDataCache.isFileStale(
            fileName: "rudolstadt_data.json"
        )
    }

    func refreshOnAppActive(now: Date = .now) async {
        if ScreenshotRuntime.isEnabled {
            await refreshRecommendations(now: ScreenshotRuntime.referenceDate)
            return
        }

        guard !isRefreshingAppState else {
            AppLog.app.debug("Skipped app-active refresh because one is already running")
            return
        }

        if
            let lastRefresh = lastAppStateRefreshAt,
            now.timeIntervalSince(lastRefresh) < 20,
            case .success = festivalData
        {
            await refreshRecommendations(now: now)
            return
        }

        isRefreshingAppState = true
        defer {
            isRefreshingAppState = false
            lastAppStateRefreshAt = now
        }

        AppLog.app.info("Refreshing app state after becoming active")
        await loadOrRefreshFestivalDataIfNeeded()
        await loadArtistLinksIfNeeded()
        await refreshNewsIfNecessary()
        await refreshRecommendations()
        AppLog.app.info("Finished refreshing app state")
    }

    func loadFestivalContentForAppLaunch(now: Date = .now) async {
        guard !hasLoadedFestivalContentForAppLaunch else {
            return
        }

        if ScreenshotRuntime.isEnabled {
            await loadArtistLinksIfNeeded()
            await refreshRecommendations(now: ScreenshotRuntime.referenceDate)
            hasLoadedFestivalContentForAppLaunch = true
            return
        }

        AppLog.app.info("Loading festival content for app launch")
        await loadOrRefreshFestivalDataIfNeeded()
        await loadArtistLinksIfNeeded()
        await refreshRecommendations(now: now)
        if case .success = festivalData {
            hasLoadedFestivalContentForAppLaunch = true
        }
        lastAppStateRefreshAt = now
        AppLog.app.info("Finished loading festival content for app launch")

        refreshNewsAfterFestivalContentAppears()
    }

    private func refreshNewsAfterFestivalContentAppears() {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self else {
                return
            }
            await self.refreshNewsIfNecessary()
        }
    }

    private func downloadAndSetFestivalData(
        resultFromCache: FileLoadingResult<FestivalData>,
        preserveCurrentDataOnFailure: Bool
    ) async {
        if case .stale(let loadedData) = resultFromCache {
            festivalData = .success(loadedData)
        }
        do {
            let apiData = try await festivalDataFetcher.fetchFestivalData()
            let storedFile = festivalDataCache.storeAPIRudolstadtDataToFile(
                data: apiData,
                fileName: "rudolstadt_data.json"
            )
            if !storedFile {
                AppLog.data.error("Downloaded festival data but failed to cache it")
            }
            refreshFestivalDataDownloadMetadata()
            let entities = convertAPIRudolstadtDataToEntities(
                apiData: apiData,
                extraData: extraData ?? ExtraDataCollection.empty()
            )
            AppLog.data.info(
                "Downloaded festival data with \(entities.artists.count) artists, \(entities.events.count) events, and \(entities.stages.count) stages"
            )
            festivalData = .success(entities)
            isUsingBundledFestivalDataBackup = false
            festivalDataFallbackStatus = nil
        } catch {
            AppLog.data.error(
                "Festival data refresh failed: \(error.localizedDescription, privacy: .public)"
            )
            setFestivalDataAfterFailedDownload(
                resultFromCache: resultFromCache,
                preserveCurrentDataOnFailure: preserveCurrentDataOnFailure,
                error: error
            )
            refreshFestivalDataDownloadMetadata()
        }
    }

    private func setFestivalDataAfterFailedDownload(
        resultFromCache: FileLoadingResult<FestivalData>,
        preserveCurrentDataOnFailure: Bool,
        error: Error
    ) {
        if case .stale(let loadedData) = resultFromCache {
            festivalData = .success(loadedData)
            isUsingBundledFestivalDataBackup = false
            festivalDataFallbackStatus = FestivalDataFallbackStatus(
                source: .staleCache,
                failure: festivalDataDownloadFailure(from: error),
                checkedAt: .now
            )
            AppLog.data.info(
                "Falling back to stale cached festival data after refresh failure"
            )
        } else if preserveCurrentDataOnFailure {
            updateCurrentFestivalDataFallbackStatusAfterFailedRefresh(error)
            AppLog.data.info(
                "Keeping currently loaded festival data after refresh failure"
            )
        } else if loadBundledFestivalDataBackup(after: error) {
            AppLog.data.info("Using bundled festival data backup after refresh failure")
        } else {
            festivalData = .failure(failureReasonForDownloadFailure(error))
            AppLog.data.error("Festival data refresh failed and no cached data was available")
        }
    }

    private func updateCurrentFestivalDataFallbackStatusAfterFailedRefresh(_ error: Error) {
        guard isUsingBundledFestivalDataBackup else {
            return
        }

        festivalDataFallbackStatus = FestivalDataFallbackStatus(
            source: .bundledBackup,
            failure: festivalDataDownloadFailure(from: error),
            checkedAt: .now
        )
    }

    private func loadBundledFestivalDataBackup(after error: Error) -> Bool {
        let result = festivalDataCache.loadBundledFestivalDataBackup(
            extraData: extraData ?? ExtraDataCollection.empty()
        )

        switch result {
        case .loaded(let backupData), .stale(let backupData):
            festivalData = .success(backupData)
            isUsingBundledFestivalDataBackup = true
            festivalDataFallbackStatus = FestivalDataFallbackStatus(
                source: .bundledBackup,
                failure: festivalDataDownloadFailure(from: error),
                checkedAt: .now
            )
            return true
        case .notFound, .unparsable:
            return false
        }
    }

    private func failureReasonForDownloadFailure(_ error: Error) -> FailureReason {
        guard let apiClientError = error as? APIClientError else {
            return .apiNotResponding
        }

        switch apiClientError {
        case .httpStatus(_, let statusCode, _) where (500...599).contains(statusCode):
            return .festivalServerError
        case .invalidResponse(_), .httpStatus(_, _, _), .decoding(_, _, _):
            return .apiNotResponding
        }
    }

    private func festivalDataDownloadFailure(
        from error: Error
    ) -> FestivalDataDownloadFailure {
        if let apiClientError = error as? APIClientError {
            switch apiClientError {
            case .httpStatus(_, let statusCode, _) where (500...599).contains(statusCode):
                return FestivalDataDownloadFailure(
                    owner: .festivalSide,
                    httpStatusCode: statusCode
                )
            case .httpStatus(_, let statusCode, _) where (400...499).contains(statusCode):
                return FestivalDataDownloadFailure(
                    owner: .appSide,
                    httpStatusCode: statusCode
                )
            case .httpStatus(_, let statusCode, _):
                return FestivalDataDownloadFailure(
                    owner: .unknown,
                    httpStatusCode: statusCode
                )
            case .invalidResponse, .decoding:
                return FestivalDataDownloadFailure(owner: .appSide)
            }
        }

        if error is URLError {
            return FestivalDataDownloadFailure(owner: .connection)
        }

        return FestivalDataDownloadFailure(owner: .unknown)
    }

    func refreshNewsIfNecessary() async {
        guard !ScreenshotRuntime.isEnabled else {
            return
        }

        let result = await newsService.refreshNewsIfNecessary()
        news = LoadingEntity(from: result)
    }

    private func buildRecommendationSnapshot(
        festivalData: FestivalData,
        savedEventIds: [Int],
        ratings: [String: Int],
        now: Date
    ) async -> RecommendationSnapshot {
        let recommendationService = self.recommendationService
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let snapshot = recommendationService.buildSnapshot(
                    data: festivalData,
                    savedEventIds: savedEventIds,
                    ratings: ratings,
                    now: now
                )
                continuation.resume(returning: snapshot)
            }
        }
    }

    private func loadCachedFestivalData(
        extraData: ExtraDataCollection
    ) async -> FileLoadingResult<FestivalData> {
        let festivalDataCache = self.festivalDataCache
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = festivalDataCache.loadFestivalDataFromFile(
                    extraData: extraData
                )
                continuation.resume(returning: result)
            }
        }
    }

    private func loadArtistLinksInBackground() async -> [String: ArtistLinks] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: parseArtistLinks())
            }
        }
    }

    private func loadOrRefreshFestivalDataIfNeeded() async {
        let shouldRefreshData: Bool
        switch festivalData {
        case .success:
            shouldRefreshData = isUsingBundledFestivalDataBackup
                || festivalDataLastDownloadDate == nil
                || festivalDataCache.isFileStale(
                    fileName: "rudolstadt_data.json"
                )
        case .loading, .failure:
            shouldRefreshData = true
        }

        guard shouldRefreshData else {
            return
        }

        await loadOrRefreshFestivalData()
    }

    private func loadCachedFestivalDataIfAvailable() {
        loadExtraData()
        let cachedResult = festivalDataCache.loadFestivalDataFromFile(
            extraData: extraData ?? ExtraDataCollection.empty()
        )
        refreshFestivalDataDownloadMetadata()

        switch cachedResult {
        case .loaded(let cachedData):
            festivalData = .success(cachedData)
            isUsingBundledFestivalDataBackup = false
            festivalDataFallbackStatus = nil
            AppLog.data.info(
                "Loaded festival data from cache with \(cachedData.artists.count) artists and \(cachedData.events.count) events"
            )
        case .stale(let cachedData):
            festivalData = .success(cachedData)
            isUsingBundledFestivalDataBackup = false
            festivalDataFallbackStatus = nil
            AppLog.data.info(
                "Loaded stale festival data from cache with \(cachedData.artists.count) artists and \(cachedData.events.count) events"
            )
        case .notFound:
            AppLog.data.info("No cached festival data available during startup")
        case .unparsable:
            AppLog.data.error("Cached festival data was unparsable during startup")
        }
    }

    private func loadBundledScreenshotData() {
        loadExtraData()
        let resolvedExtraData = extraData ?? ExtraDataCollection.empty()

        switch festivalDataCache.loadBundledFestivalDataBackup(
            extraData: resolvedExtraData
        ) {
        case .loaded(let data), .stale(let data):
            festivalData = .success(data)
            isUsingBundledFestivalDataBackup = false
            festivalDataFallbackStatus = nil
        case .notFound, .unparsable:
            festivalData = .failure(.couldNotLoadFromFile)
        }

        switch bundledNewsLoader.loadBundledNewsBackup() {
        case .loaded(let items), .stale(let items):
            news = .success(items)
        case .notFound, .unparsable:
            news = .failure(.couldNotLoadFromFile)
        }

        AppLog.data.info("Loaded deterministic bundled data for screenshots")
    }

    private func refreshFestivalDataDownloadMetadata() {
        festivalDataLastDownloadDate =
            festivalDataCache.cachedFestivalDataModificationDate()
    }
}
