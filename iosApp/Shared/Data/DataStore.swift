import Foundation
import RudolstadtCore
import OSLog
import SwiftUI

extension StringProtocol {
    func nilIfEmpty() -> Self? { isEmpty ? nil : self }
}

@MainActor
final class DataStore: ObservableObject {
    private let viewModel: FestivalViewModel
    private var observation: StateSubscription?
    // Platform services and presentation projections are keyed by the shared snapshot.
    private var nativeContexts: [Int64: FestivalData] = [:]
    private var contextSequence: Int64 = 0
    private var artistIndex: (artists: [ObjectIdentifier], localeID: String, value: ArtistOverviewIndex)?

    func artistOverviewIndex(for artists: [Artist], locale: Locale) -> ArtistOverviewIndex {
        let identity = artists.map(ObjectIdentifier.init)
        if let artistIndex, artistIndex.artists == identity, artistIndex.localeID == locale.identifier {
            return artistIndex.value
        }
        let index = ArtistOverviewIndex(artists, locale: locale)
        artistIndex = (identity, locale.identifier, index)
        return index
    }

    var festivalData: LoadingEntity<FestivalData> {
        get {
            let state = viewModel.current
            if state.phase == .ready, let snapshot = state.snapshot,
                var data = nativeContexts[snapshot.contextID]
            {
                if let source = snapshot.source.flatMap(FestivalDataSource.init(core:)) {
                    data.provenance = FestivalDataProvenance(
                        source: source,
                        dataUpdatedAt: nativeDate(
                            snapshot.updatedAt, preserving: data.provenance?.dataUpdatedAt),
                        refreshCheckedAt: nativeDate(
                            snapshot.checkedAt, preserving: data.provenance?.refreshCheckedAt),
                        omittedRecordCount: data.omittedRecordCount)
                }
                return .success(data)
            }
            return state.phase == .failed
                ? .failure(FailureReason(rawValue: state.failure ?? "") ?? .apiNotResponding) : .loading
        }
        set {
            switch newValue {
            case .success(let data): viewModel.present(snapshot: register(data))
            case .loading: viewModel.clear(failure: nil)
            case .failure(let reason): viewModel.clear(failure: reason.rawValue)
            }
        }
    }
    var loadedFestivalData: FestivalData? {
        if case .success(let data) = festivalData { return data }
        return nil
    }
    var festivalDataProvenance: FestivalDataProvenance? { loadedFestivalData?.provenance }
    var festivalDataLastDownloadDate: Date? {
        let state = viewModel.current
        let original = state.snapshot.flatMap { nativeContexts[$0.contextID]?.provenance?.dataUpdatedAt }
        return nativeDate(state.lastDownload, preserving: original)
    }

    // Keep Date's sub-microsecond precision when projecting an unchanged Unix timestamp.
    private func nativeDate(_ timestamp: KotlinDouble?, preserving original: Date?) -> Date? {
        guard let timestamp else { return nil }
        if let original, original.timeIntervalSince1970 == timestamp.doubleValue { return original }
        return Date(timeIntervalSince1970: timestamp.doubleValue)
    }
    var isUsingBundledFestivalDataBackup: Bool { festivalDataProvenance?.source == .bundledBackup }
    var festivalDataFallbackStatus: FestivalDataFallbackStatus? {
        guard let value = viewModel.current.fallback else { return nil }
        return FestivalDataFallbackStatus(
            source: value.source == "bundledBackup" ? .bundledBackup : .staleCache,
            failure: value.failure.native, checkedAt: Date(timeIntervalSince1970: value.checkedAt))
    }
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

    var metadata: FestivalMetadata { adapter.metadata }
    var features: FestivalFeatures { loadedFestivalData?.features ?? FestivalFeatures() }
    var hasNews: Bool { newsStore.isSupported }
    var automaticPlanning: FeatureAvailability<any FestivalAutomaticPlanningProviding> { features.automaticPlanning }
    var isFestivalDataCacheStale: Bool {
        viewModel.isCacheStale()
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
        self.viewModel = FestivalViewModel(refreshable: resolvedAdapter.loadingStrategy == .refreshable)
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
        observation = viewModel.observe { [weak self] _ in
            guard let self else { return }
            self.objectWillChange.send()
            if let id = self.viewModel.current.snapshot?.contextID {
                self.nativeContexts = self.nativeContexts.filter { $0.key == id }
            }
            self.onWatchSnapshotInputsChange?()
        }
        if loadInitialData {
            if ScreenshotRuntime.isEnabled { loadBundledScreenshotData() }
            else {
                do {
                    if let cached = try resolvedAdapter.loadInitialCachedProgram() {
                        let prepared = try cached.prepared(using: metadata)
                        viewModel.restoreInitial(
                            snapshot: register(prepared), now: Date.now.timeIntervalSince1970)
                    }
                } catch {
                    AppLog.data.error(
                        "Cannot restore initial program cache: \(error.localizedDescription)")
                }
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

    deinit {
        observation?.cancel()
        pendingRecommendationRefreshTask?.cancel()
        initialNewsTask?.cancel()
        newsRefreshTask?.cancel()
        downloadTask?.cancel()
    }

    private func register(_ data: FestivalData) -> FestivalSnapshot {
        var data = data
        data.detailCatalog = data.makeDetailCatalog()
        contextSequence += 1
        nativeContexts[contextSequence] = data
        let planning: String
        switch data.features.automaticPlanning {
        case .unsupported: planning = data.metadata == nil ? "available" : "unsupported"
        case .unavailable: planning = "unavailable"
        case .available: planning = "available"
        }
        return FestivalSnapshot(
            program: data.coreProgram, days: data.days.map(\.core), contextID: contextSequence,
            source: data.provenance?.source.core,
            updatedAt: data.provenance?.dataUpdatedAt.map { KotlinDouble(value: $0.timeIntervalSince1970) },
            checkedAt: data.provenance?.refreshCheckedAt.map {
                KotlinDouble(value: $0.timeIntervalSince1970)
            }, planning: planning)
    }

    // Executes platform effects; ordering, fallback and stale-result decisions belong to Kotlin.
    func loadOrRefreshFestivalData() async {
        downloadTask?.cancel()
        var request = viewModel.beginLoad()
        while request.effect != .none {
            let token = request.generation
            guard !Task.isCancelled, viewModel.isCurrent(token: token) else { return }
            do {
                let data: FestivalData?
                switch request.effect {
                case .readCache: data = try await adapter.loadCachedProgram()
                case .readBundle: data = try await adapter.loadBundledProgram()
                case .refresh:
                    let adapter = self.adapter
                    let task = Task { try await adapter.refresh() }
                    downloadTask = task
                    defer { if viewModel.isCurrent(token: token) { downloadTask = nil } }
                    data = try await withTaskCancellationHandler {
                        try await task.value
                    } onCancel: {
                        task.cancel()
                    }
                default: return
                }
                guard !Task.isCancelled, viewModel.isCurrent(token: token) else { return }
                let snapshot = try data.map { register(try $0.prepared(using: metadata)) }
                switch request.effect {
                case .readCache:
                    request = viewModel.cacheReceived(token: token, snapshot: snapshot, failed: false)
                case .readBundle: request = viewModel.bundleReceived(token: token, snapshot: snapshot)
                case .refresh:
                    guard let snapshot else { return }
                    request = viewModel.remoteReceived(token: token, snapshot: snapshot)
                default: return
                }
            } catch {
                guard !Task.isCancelled, viewModel.isCurrent(token: token), !(error is CancellationError)
                else { return }
                switch request.effect {
                case .readCache: request = viewModel.cacheReceived(token: token, snapshot: nil, failed: true)
                case .readBundle: request = viewModel.bundleReceived(token: token, snapshot: nil)
                case .refresh:
                    request = viewModel.remoteFailed(
                        token: token, failure: error.appFailure,
                        now: Date.now.timeIntervalSince1970)
                default: return
                }
            }
        }
    }

    func install(_ data: FestivalData) throws {
        viewModel.present(snapshot: register(try data.prepared(using: metadata)))
    }

    func deleteCachedFestivalData() async -> Bool {
        do {
            try await adapter.deleteCache()
            viewModel.cacheDeleted()
            return true
        } catch {
            AppLog.data.error("Cannot delete festival cache: \(error.localizedDescription)")
            return false
        }
    }

    func refreshRecommendations(now: Date = .now) async {
        let token = recommendationStore.viewModel.beginCalculation(
            hasProgram: loadedFestivalData != nil,
            planning: viewModel.current.snapshot?.planning ?? "available")
        guard let current = token?.int64Value, let data = loadedFestivalData else { return }
        let service = recommendationService
        let saved = festivalProfileStore.savedEvents
        let ratings = festivalProfileStore.ratings
        let result = await withTaskGroup(of: RecommendationSnapshot.self) { group in
            group.addTask(priority: .userInitiated) {
                service.buildSnapshot(data: data, savedEventIds: saved, ratings: ratings, now: now)
            }
            return await group.next() ?? RecommendationSnapshot(recommendedEventIds: [], estimatedEventDurations: [:])
        }
        guard !Task.isCancelled else { return }
        recommendationStore.update(result, generatedAt: now, token: current)
    }

    func scheduleRecommendationRefresh(now: Date = .now) {
        pendingRecommendationRefreshTask?.cancel()
        _ = recommendationStore.viewModel.inputsChanged()
        guard loadedFestivalData?.metadata == nil || automaticPlanning.value != nil else { return }
        pendingRecommendationRefreshTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(self?.viewModel.recommendationDebounceMillis ?? 180))
            } catch { return }
            await self?.refreshRecommendations(now: now)
        }
    }

    func refreshOnAppActive(now: Date = .now) async {
        await execute(
            viewModel.activePlan(now: now.timeIntervalSince1970, screenshot: ScreenshotRuntime.isEnabled),
            now: now)
    }
    func loadFestivalContentForAppLaunch(now: Date = .now) async {
        await execute(
            viewModel.launchPlan(now: now.timeIntervalSince1970, screenshot: ScreenshotRuntime.isEnabled),
            now: now)
    }
    private func execute(_ plan: AppRefreshPlan, now: Date) async {
        guard plan.accepted else { return }
        defer { viewModel.completePlan(plan: plan, now: now.timeIntervalSince1970) }
        for effect in plan.effects {
            guard !Task.isCancelled else { return }
            switch effect {
            case .loadProgram: await loadOrRefreshFestivalData()
            case .refreshRecommendations:
                await refreshRecommendations(
                    now: ScreenshotRuntime.isEnabled ? ScreenshotRuntime.referenceDate : now)
            case .refreshNews: await newsStore.refreshNewsIfNecessary()
            case .deferNews:
                newsRefreshTask?.cancel()
                let delay = viewModel.newsDelayMillis
                newsRefreshTask = Task { [weak self] in
                    do { try await Task.sleep(for: .milliseconds(delay)) } catch { return }
                    await self?.newsStore.refreshNewsIfNecessary()
                }
            default: break
            }
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
