import Combine
import Foundation

enum NewsNotificationDestination {
    case item(NewsItem)
    case loading
    case list
}

@MainActor
final class NewsStore: ObservableObject {
    @Published private(set) var news: LoadingEntity<[NewsItem]> = .loading

    @Published private(set) var source: NewsSource?
    @Published private(set) var notice: NewsNotice?

    private let expectedIdentity: FestivalIdentity?
    private let service: NewsService?
    private let feature: FeatureAvailability<any FestivalNewsProviding>
    private var provider: (any FestivalNewsProviding)? { feature.value }
    @Published private(set) var snapshot: FestivalNewsSnapshot?
    var isSupported: Bool { service != nil || feature.isSupported }
    // Keep the existing rich news UI for the original NewsItem integration.
    var usesLegacyPresentation: Bool { service != nil || provider is RudolstadtNewsAdapter }
    private let bundledNewsLoader: (any BundledNewsLoading)?

    init(service: NewsService, bundledNewsLoader: any BundledNewsLoading) {
        self.expectedIdentity = FestivalEdition.current.identity
        self.feature = .unsupported
        self.service = service
        self.bundledNewsLoader = bundledNewsLoader
    }

    init(feature: FeatureAvailability<any FestivalNewsProviding>, identity: FestivalIdentity) {
        self.expectedIdentity = identity
        self.feature = feature
        self.service = nil
        self.bundledNewsLoader = nil
    }

    func loadCachedNewsIfAvailable() {
        if let cachedNews = service?.loadCachedNews() {
            news = .success(cachedNews)
            source = service?.source
        }
    }

    func loadCachedSnapshot() async {
        guard snapshot == nil, let provider else { return }
        do {
            if let value = try await provider.loadCachedNews(), !Task.isCancelled, snapshot == nil { try apply(value) }
        } catch { AppLog.news.error("Cannot read cached news: \(error.localizedDescription)") }
    }

    func refreshNewsIfNecessary() async {
        guard !ScreenshotRuntime.isEnabled else {
            return
        }
        if let provider {
            do {
                if snapshot == nil, let cached = try await provider.loadCachedNews() { try apply(cached) }
                let value = try await provider.refreshNews()
                guard !Task.isCancelled else { return }
                try apply(value)
            } catch is CancellationError { return }
            catch {
                guard !Task.isCancelled else { return }
                if snapshot == nil {
                    do { if let bundled = try await provider.loadBundledNews() { try apply(bundled) } }
                    catch { AppLog.news.error("Cannot load news backup: \(error.localizedDescription)") }
                }
                notice = .refreshFailed
                if snapshot == nil { news = .failure(.apiNotResponding) }
            }
            return
        }
        guard let service else {
            if feature.isSupported { news = .failure(.apiNotResponding) }
            return
        }
        let result = await service.refreshNewsIfNecessary()
        guard !Task.isCancelled else { return }
        news = LoadingEntity(from: result)
        source = service.source
        notice = service.notice
    }

    private func apply(_ value: FestivalNewsSnapshot) throws {
        guard expectedIdentity == nil || value.identity == expectedIdentity,
              Set(value.items.map(\.id)).count == value.items.count else { throw FestivalLoadingError.wrongIdentity }
        snapshot = value
        notice = value.notice == nil ? nil : .refreshFailed
        source = value.provenance.source == .remote ? .remote : value.provenance.source == .screenshot ? .screenshot : .cache
        news = .success(value.items.flatMap { item -> [NewsItem] in
            guard let id = Int(item.id) else { return [] }
            return item.title.availableLanguages.sorted { $0.identifier < $1.identifier }.map { language in
                let locale = Locale(identifier: language.identifier)
                let date = item.publishedAt.map { FestivalDateUtilities.format($0, pattern: "dd.MM.yyyy", locale: locale) } ?? ""
                let time = item.publishedAt.map { FestivalDateUtilities.format($0, pattern: "HH:mm", locale: locale) } ?? ""
                return NewsItem(id: id, languageCode: language.identifier, dateAsString: date, timeAsString: time,
                    shortDescription: item.title.resolved(locale: locale), longDescription: item.summary?.resolved(locale: locale) ?? "",
                    content: item.body.text.resolved(locale: locale))
            }
        })
    }

    func notificationDestination(id: Int, hasRefreshed: Bool) -> NewsNotificationDestination {
        if case .success(let items) = news, let item = items.first(where: { $0.id == id }) {
            return .item(item)
        }
        return hasRefreshed ? .list : .loading
    }

    func loadBundledScreenshotData() {
        source = .screenshot
        notice = nil
        if let provider = provider as? RudolstadtNewsAdapter {
            do { if let value = try provider.bundledSnapshot(source: .screenshot) { try apply(value) } }
            catch { news = .failure(.couldNotLoadFromFile) }
            return
        }
        guard let bundledNewsLoader else { return }
        switch bundledNewsLoader.loadBundledNewsBackup() {
        case .loaded(let items), .stale(let items):
            news = .success(items)
        case .notFound, .unparsable:
            news = .failure(.couldNotLoadFromFile)
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
        let grouped = Dictionary(grouping: items, by: \.id)
        let values = grouped.keys.sorted(by: >).compactMap { id -> FestivalNewsItem? in
            guard let item = grouped[id]?.first else { return nil }
            func text(_ key: KeyPath<NewsItem, String>) -> LocalizedText {
                LocalizedText(values: Dictionary(grouped[id, default: []].map {
                    (LanguageTag($0.languageCode), $0[keyPath: key])
                }, uniquingKeysWith: { first, _ in first }))
            }
            return FestivalNewsItem(id: String(id), title: text(\.shortDescription), summary: text(\.longDescription),
                body: FestivalContent(text: text(\.content), format: .html), imageURL: nil,
                publishedAt: FestivalDateUtilities.parse(item.dateAsString + " " + item.timeAsString, format: "dd.MM.yyyy HH:mm"),
                updatedAt: nil, sourceURL: nil, links: [], relatedDestinations: [])
        }
        var snapshot = FestivalNewsSnapshot(identity: identity, items: values,
            provenance: FestivalDataProvenance(source: source, dataUpdatedAt: nil, refreshCheckedAt: nil))
        if let notice = service.notice {
            snapshot.notice = bilingual(
                String(localized: String.LocalizationValue(notice.rawValue), locale: Locale(identifier: "de")),
                String(localized: String.LocalizationValue(notice.rawValue), locale: Locale(identifier: "en")))
        }
        return snapshot
    }
}
