import Combine
import Foundation
import RudolstadtCore

enum NewsNotificationDestination {
    case item(NewsItem)
    case loading
    case list
}

@MainActor
final class NewsStore: KotlinStateStore<RudolstadtCore.NewsState> {
    private let viewModel: NewsViewModel
    var source: NewsSource? { viewModel.current.source.flatMap(NewsSource.init(core:)) }
    var notice: NewsNotice? { viewModel.current.notice.flatMap(NewsNotice.init(rawValue:)) }
    private let service: NewsService?
    private let feature: FeatureAvailability<any FestivalNewsProviding>
    private var provider: (any FestivalNewsProviding)? { feature.value }
    var snapshot: FestivalNewsSnapshot? { viewModel.current.snapshot }
    var isSupported: Bool { service != nil || feature.isSupported }
    // Keep the existing rich news UI for the original NewsItem integration.
    var usesLegacyPresentation: Bool { service != nil || provider is RudolstadtNewsAdapter }
    private let bundledNewsLoader: (any BundledNewsLoading)?

    init(service: NewsService, bundledNewsLoader: any BundledNewsLoading) {
        let model = NewsViewModel(
            festivalID: FestivalEdition.current.identity.festivalID,
            editionID: FestivalEdition.current.identity.editionID)
        self.viewModel = model
        self.feature = .unsupported
        self.service = service
        self.bundledNewsLoader = bundledNewsLoader
        super.init(current: { model.current }, observe: model.observe)
    }

    init(feature: FeatureAvailability<any FestivalNewsProviding>, identity: FestivalIdentity) {
        let model = NewsViewModel(festivalID: identity.festivalID, editionID: identity.editionID)
        self.viewModel = model
        self.feature = feature
        self.service = nil
        self.bundledNewsLoader = nil
        super.init(current: { model.current }, observe: model.observe)
    }

    private func present(_ result: LoadingResult<[NewsItem]>, source: NewsSource?, notice: NewsNotice?) {
        switch result {
        case .success(let items):
            viewModel.present(items: items, source: source?.core, notice: notice?.rawValue, failure: nil)
        case .failure(let reason):
            viewModel.present(
                items: [], source: source?.core, notice: notice?.rawValue, failure: reason.rawValue)
        }
    }
    func loadCachedNewsIfAvailable() {
        if let cached = service?.loadCachedNews() {
            present(.success(cached), source: service?.source, notice: nil)
        }
    }
    func loadCachedSnapshot() async {
        guard snapshot == nil, let provider else { return }
        do {
            if let value = try await provider.loadCachedNews(), !Task.isCancelled, snapshot == nil {
                try apply(value)
            }
        } catch { AppLog.news.error("Cannot read cached news: \(error.localizedDescription)") }
    }
    func refreshNewsIfNecessary() async {
        guard !ScreenshotRuntime.isEnabled else { return }
        if let provider {
            var request = viewModel.beginRefresh()
            while request.effect != .none {
                let token = request.generation
                guard !Task.isCancelled, viewModel.isCurrent(token: token) else { return }
                let effect = request.effect
                do {
                    let value: FestivalNewsSnapshot?
                    switch effect {
                    case .readCache: value = try await provider.loadCachedNews()
                    case .readBundle: value = try await provider.loadBundledNews()
                    case .refresh: value = try await provider.refreshNews()
                    default: return
                    }
                    guard !Task.isCancelled, viewModel.isCurrent(token: token) else { return }
                    if let value { try apply(value) }
                    switch effect {
                    case .readCache: request = viewModel.cacheFinished(token: token)
                    case .readBundle: request = viewModel.bundleFinished(token: token)
                    default: return
                    }
                } catch {
                    guard !Task.isCancelled, !(error is CancellationError), viewModel.isCurrent(token: token)
                    else { return }
                    switch effect {
                    case .readCache: request = viewModel.cacheFinished(token: token)
                    case .readBundle: request = viewModel.bundleFinished(token: token)
                    default: request = viewModel.refreshFailed(token: token)
                    }
                }
            }
            return
        }
        guard let service else {
            if feature.isSupported { present(.failure(.apiNotResponding), source: nil, notice: nil) }
            return
        }
        let result = await service.refreshNewsIfNecessary()
        guard !Task.isCancelled else { return }
        present(result, source: service.source, notice: service.notice)
    }

    private func apply(_ value: FestivalNewsSnapshot) throws {
        try viewModel.applySnapshot(snapshot: value)
    }

    func notificationDestination(id: Int, hasRefreshed: Bool) -> NewsNotificationDestination {
        switch viewModel.notificationDestination(id: Int64(id), refreshed: hasRefreshed) {
        case "item":
            if let item = viewModel.current.items.first(where: { $0.id == id }) { return .item(item) }
            return .list
        case "loading": return .loading
        default: return .list
        }
    }
    func loadBundledScreenshotData() {
        if let provider = provider as? RudolstadtNewsAdapter {
            do { if let value = try provider.bundledSnapshot(source: .screenshot) { try apply(value) } }
            catch { present(.failure(.couldNotLoadFromFile), source: .screenshot, notice: nil) }
            return
        }
        guard let bundledNewsLoader else { return }
        switch bundledNewsLoader.loadBundledNewsBackup() {
        case .loaded(let items), .stale(let items): present(.success(items), source: .screenshot, notice: nil)
        case .notFound, .unparsable:
            present(.failure(.couldNotLoadFromFile), source: .screenshot, notice: nil)
        }
    }

}


@MainActor
final class RudolstadtNewsAdapter: FestivalNewsProviding {
    private let service: NewsService
    private let loader: any BundledNewsLoading
    private let identity: FestivalIdentity

    init(service: NewsService, loader: any BundledNewsLoading, identity: FestivalIdentity) {
        self.service = service
        self.loader = loader
        self.identity = identity
    }

    func loadCachedNews() async throws -> FestivalNewsSnapshot? {
        service.loadCachedNews().map { makeSnapshot($0, source: .cache) }
    }

    func loadBundledNews() async throws -> FestivalNewsSnapshot? { try bundledSnapshot() }

    func bundledSnapshot(source: FestivalDataSource = .bundledBackup) throws -> FestivalNewsSnapshot? {
        switch loader.loadBundledNewsBackup() {
        case .loaded(let items), .stale(let items): return makeSnapshot(items, source: source)
        case .notFound: return nil
        case .unparsable: throw FestivalLoadingError.invalidSnapshot
        }
    }

    func refreshNews() async throws -> FestivalNewsSnapshot {
        switch await service.refreshNewsIfNecessary() {
        case .success(let items):
            let source: FestivalDataSource
            switch service.source {
            case .remote: source = .remote
            case .bundle: source = .bundledBackup
            case .screenshot: source = .screenshot
            case .cache, .none: source = .cache
            }
            return makeSnapshot(items, source: source)
        case .failure: throw FestivalLoadingError.unavailable
        }
    }

    func deleteCache() async throws {
        guard await service.deleteNewsCache() else { throw FestivalLoadingError.cacheDeletionFailed }
    }

    private func makeSnapshot(_ items: [NewsItem], source: FestivalDataSource) -> FestivalNewsSnapshot {
        NewsSnapshots.shared.fromMessages(
            items: items, festivalID: identity.festivalID, editionID: identity.editionID,
            source: source.core, notice: service.notice?.rawValue)
    }
}
