import Foundation
import OSLog
import SwiftUI

extension StringProtocol {
    func nilIfEmpty() -> Self? { isEmpty ? nil : self }
}

@MainActor
final class DataStore: ObservableObject {
    @Published var festivalData: LoadingEntity<FestivalData> = .loading {
        didSet { onWatchSnapshotInputsChange?() }
    }
    var loadedFestivalData: FestivalData? {
        if case .success(let data) = festivalData { return data }
        return nil
    }
    var festivalDataProvenance: FestivalDataProvenance? { loadedFestivalData?.provenance }
    // Cache deletion changes this independently of the still-visible program's provenance.
    @Published private(set) var festivalDataLastDownloadDate: Date?
    var isUsingBundledFestivalDataBackup: Bool { festivalDataProvenance?.source == .bundledBackup }
    @Published var festivalDataFallbackStatus: FestivalDataFallbackStatus?
    let newsStore: NewsStore
    let recommendationStore = RecommendationStore()
    let edition: FestivalEdition
    let adapter: any FestivalAdapter
    let recommendationService: any RecommendationProviding
    let festivalProfileStore: FestivalProfileStore
    nonisolated static let year = FestivalConfiguration.year
    var onWatchSnapshotInputsChange: (() -> Void)?
    private var pendingRecommendationRefreshTask: Task<Void, Never>?
    private var initialNewsTask: Task<Void, Never>?
    private var newsRefreshTask: Task<Void, Never>?
    private var downloadTask: Task<FestivalData, Error>?
    private var generation = 0
    private var recommendationGeneration = 0
    private var lastAppStateRefreshAt: Date?
    private var isRefreshingAppState = false
    private var hasLoadedFestivalContentForAppLaunch = false

    var metadata: FestivalMetadata { adapter.metadata }
    var features: FestivalFeatures { loadedFestivalData?.features ?? FestivalFeatures() }
    var hasNews: Bool { newsStore.isSupported }
    var automaticPlanning: FeatureAvailability<any FestivalAutomaticPlanningProviding> { features.automaticPlanning }
    var isFestivalDataCacheStale: Bool {
        guard let source = festivalDataProvenance?.source else { return true }
        return source == .staleCache || source == .bundledBackup
    }
    var artistLinks: [String: ArtistLinks]? {
        guard case .success(let data) = festivalData else { return nil }
        var result = [String: ArtistLinks]()
        for artist in data.artists {
            let links = artist.additionalLinks
            let spotify = links.first { $0.id == "spotify" }?.destination.absoluteString
            let apple = links.first { $0.id == "appleMusic" }?.destination.absoluteString
            guard spotify != nil || apple != nil else { continue }
            let preview: ArtistAppleMusicPreviewSelection
            switch artist.musicPreview {
            case .automatic: preview = .automatic
            case .disabled: preview = .disabled
            case .songURL(let url): preview = .songURL(url.absoluteString)
            }
            let value = ArtistLinks(spotifyURL: spotify, appleMusicURL: apple, appleMusicPreviewSelection: preview)
            result[artist.name] = value
            result[normalizeArtistLinkKey(artist.name)] = value
        }
        return result
    }

    var browseTaxonomy: [BrowseTaxonomyEntry] {
        (features.groupings.value?.groupings.first { $0.id == "genre" }?.groups ?? []).map {
            BrowseTaxonomyEntry(id: $0.id, labelDE: $0.title.resolved(locale: Locale(identifier: "de")),
                                labelEN: $0.title.resolved(locale: Locale(identifier: "en")))
        }
    }
    func localizedBrowseGenreLabel(for id: String) -> String {
        features.groupings.value?.groupings.flatMap(\.groups).first { $0.id == id }?.title.resolved() ?? id
    }

    init(festivalProfileStore: FestivalProfileStore? = nil, userSettings: UserSettings? = nil,
         newsService: NewsService? = nil, recommendationService: RecommendationProviding? = nil,
         edition: FestivalEdition = .current, festivalAdapter: (any FestivalAdapter)? = nil,
         bundledNewsLoader: (any BundledNewsLoading)? = nil, loadInitialData: Bool = true) {
        let settings = userSettings ?? UserSettings()
        let resolvedAdapter: any FestivalAdapter
        if let festivalAdapter { resolvedAdapter = festivalAdapter }
        else if let registered = FestivalRegistry.catalog.adapter(for: edition.identity) { resolvedAdapter = registered }
        else { preconditionFailure("Unregistered festival") }
        let resolvedEdition = FestivalEdition(metadata: resolvedAdapter.metadata)
        self.edition = resolvedEdition
        self.adapter = resolvedAdapter
        if let festivalProfileStore { self.festivalProfileStore = festivalProfileStore }
        else {
            self.festivalProfileStore = FestivalRegistry.makeProfileStore(metadata: resolvedAdapter.metadata, defaults: settings.userDefaults)
        }
        let declared = resolvedAdapter.metadata.userDataPolicy
        precondition(declared.savedEvents != .readOnly || self.festivalProfileStore.userDataPolicy.savedEvents != .editable)
        precondition(declared.artistRatings != .readOnly || self.festivalProfileStore.userDataPolicy.artistRatings != .editable)
        precondition(declared.artistNotes != .readOnly || self.festivalProfileStore.userDataPolicy.artistNotes != .editable)
        if let newsService {
            self.newsStore = NewsStore(service: newsService, bundledNewsLoader: bundledNewsLoader ?? Self.makeDefaultDataLoader())
        } else {
            self.newsStore = NewsStore(feature: resolvedAdapter.services.news, identity: resolvedAdapter.metadata.identity)
        }
        self.recommendationService = recommendationService ?? RecommendationService(calendar: resolvedAdapter.metadata.calendar)
        if loadInitialData {
            if ScreenshotRuntime.isEnabled { loadBundledScreenshotData() }
            else {
                newsStore.loadCachedNewsIfAvailable()
                let news = newsStore
                initialNewsTask = Task { await news.loadCachedSnapshot() }
            }
        }
    }

    static func makeDefaultDataLoader() -> DataLoader {
        do {
            return DataLoader(cacheURL: try FileManager.default.url(for: .cachesDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true))
        } catch { preconditionFailure("Cannot resolve cache directory: \(error)") }
    }

    func loadOrRefreshFestivalData() async {
        generation += 1
        let current = generation
        downloadTask?.cancel()
        var cached: FestivalData?
        var readError: Error?
        do { cached = try await adapter.loadCachedProgram() }
        catch is CancellationError { return }
        catch { readError = error }
        guard !Task.isCancelled, current == generation else { return }
        if let cached {
            do { try install(cached) } catch { readError = error }
            if cached.provenance?.source == .cache && readError == nil { return }
        }
        if adapter.loadingStrategy == .bundledOnly {
            do {
                if let bundled = try await adapter.loadBundledProgram() {
                    guard !Task.isCancelled, current == generation else { return }
                    try install(bundled)
                    return
                }
                if loadedFestivalData == nil { festivalData = .failure(.couldNotLoadFromFile) }
            } catch is CancellationError { return }
            catch { if loadedFestivalData == nil { festivalData = .failure(.couldNotLoadFromFile) } }
            return
        }
        await refreshSnapshot(generation: current, initialError: readError)
    }

    private func refreshSnapshot(generation current: Int, initialError: Error?) async {
        let adapter = self.adapter
        let task = Task { try await adapter.refresh() }
        downloadTask = task
        defer { if current == generation { downloadTask = nil } }
        do {
            let snapshot = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            guard !Task.isCancelled, current == generation else { return }
            try install(snapshot)
            festivalDataFallbackStatus = nil
        } catch {
            guard !Task.isCancelled, current == generation, !(error is CancellationError) else { return }
            if loadedFestivalData == nil {
                do { if let bundled = try await adapter.loadBundledProgram() {
                    guard !Task.isCancelled, current == generation else { return }
                    try install(bundled)
                } } catch { AppLog.data.error("Cannot load festival backup: \(error.localizedDescription)") }
            }
            guard current == generation, !Task.isCancelled else { return }
            if var data = loadedFestivalData, let provenance = data.provenance {
                data.provenance = FestivalDataProvenance(source: provenance.source,
                    dataUpdatedAt: provenance.dataUpdatedAt, refreshCheckedAt: .now,
                    omittedRecordCount: provenance.omittedRecordCount)
                festivalData = .success(data)
                if provenance.source == .staleCache || provenance.source == .bundledBackup {
                    festivalDataFallbackStatus = FestivalDataFallbackStatus(
                        source: provenance.source == .bundledBackup ? .bundledBackup : .staleCache,
                        failure: (error as? FestivalDataProviderError)?.failure
                            ?? FestivalDataDownloadFailure(owner: error is URLError ? .connection : .unknown), checkedAt: .now)
                }
            } else if case .success = festivalData {
                // Keep confirmed data when a refresh has no usable replacement.
            } else {
                festivalData = .failure((error as? FestivalDataProviderError)?.reason
                    ?? (initialError == nil ? .apiNotResponding : .couldNotLoadFromFile))
            }
        }
    }

    func install(_ data: FestivalData) throws {
        let prepared = try data.prepared(using: metadata)
        festivalDataLastDownloadDate = prepared.provenance?.dataUpdatedAt
        festivalData = .success(prepared)
    }

    func deleteCachedFestivalData() async -> Bool {
        do {
            try await adapter.deleteCache()
            festivalDataLastDownloadDate = nil
            return true
        } catch {
            AppLog.data.error("Cannot delete festival cache: \(error.localizedDescription)")
            return false
        }
    }

    func refreshRecommendations(now: Date = .now) async {
        guard case .success(let data) = festivalData else { recommendationStore.reset(); return }
        if data.metadata != nil {
            switch automaticPlanning {
            case .unsupported: recommendationStore.disable(); return
            case .unavailable: recommendationStore.unavailable(); return
            case .available: break
            }
        }
        recommendationGeneration += 1
        let current = recommendationGeneration
        recommendationStore.beginRefresh()
        let service = recommendationService
        let saved = festivalProfileStore.savedEvents
        let ratings = festivalProfileStore.ratings
        let result = await withTaskGroup(of: RecommendationSnapshot.self) { group in
            group.addTask(priority: .userInitiated) {
                service.buildSnapshot(data: data, savedEventIds: saved, ratings: ratings, now: now)
            }
            return await group.next() ?? RecommendationSnapshot(recommendedEventIds: [], estimatedEventDurations: [:])
        }
        guard current == recommendationGeneration, !Task.isCancelled else { return }
        recommendationStore.update(result, generatedAt: now)
    }

    func scheduleRecommendationRefresh(now: Date = .now) {
        pendingRecommendationRefreshTask?.cancel()
        guard loadedFestivalData?.metadata == nil || automaticPlanning.value != nil else { return }
        pendingRecommendationRefreshTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
            await self?.refreshRecommendations(now: now)
        }
    }

    func refreshOnAppActive(now: Date = .now) async {
        guard !isRefreshingAppState else { return }
        isRefreshingAppState = true
        defer { isRefreshingAppState = false; lastAppStateRefreshAt = now }
        if ScreenshotRuntime.isEnabled { await refreshRecommendations(now: ScreenshotRuntime.referenceDate); return }
        if loadedFestivalData == nil || (adapter.loadingStrategy == .refreshable && (isFestivalDataCacheStale || lastAppStateRefreshAt.map({ now.timeIntervalSince($0) >= 20 }) != false)) {
            await loadOrRefreshFestivalData()
        }
        await newsStore.refreshNewsIfNecessary()
        await refreshRecommendations(now: now)
    }

    func loadFestivalContentForAppLaunch(now: Date = .now) async {
        guard !hasLoadedFestivalContentForAppLaunch else { await refreshOnAppActive(now: now); return }
        if !ScreenshotRuntime.isEnabled { await loadOrRefreshFestivalData() }
        guard !Task.isCancelled else { return }
        await refreshRecommendations(now: ScreenshotRuntime.isEnabled ? ScreenshotRuntime.referenceDate : now)
        hasLoadedFestivalContentForAppLaunch = loadedFestivalData != nil
        newsRefreshTask?.cancel()
        newsRefreshTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            await self?.newsStore.refreshNewsIfNecessary()
        }
    }

    private func loadBundledScreenshotData() {
        // Screenshot seeding is synchronous by design and belongs to this explicit data source.
        guard let adapter = adapter as? FestivalSourceAdapter else { return }
        switch adapter.source.loadBundledData() {
        case .loaded(let data), .stale(let data):
            do { try install(adapter.prepare(data, source: .screenshot, updatedAt: ScreenshotRuntime.referenceDate)) }
            catch { festivalData = .failure(.couldNotLoadFromFile) }
        case .notFound, .unparsable: festivalData = .failure(.couldNotLoadFromFile)
        }
        newsStore.loadBundledScreenshotData()
    }
}
