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

    private let service: NewsService
    private let bundledNewsLoader: any BundledNewsLoading

    init(service: NewsService, bundledNewsLoader: any BundledNewsLoading) {
        self.service = service
        self.bundledNewsLoader = bundledNewsLoader
    }

    func loadCachedNewsIfAvailable() {
        if let cachedNews = service.loadCachedNews() {
            news = .success(cachedNews)
            source = service.source
        }
    }

    func refreshNewsIfNecessary() async {
        guard !ScreenshotRuntime.isEnabled else {
            return
        }
        let result = await service.refreshNewsIfNecessary()
        guard !Task.isCancelled else { return }
        news = LoadingEntity(from: result)
        source = service.source
        notice = service.notice
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
        switch bundledNewsLoader.loadBundledNewsBackup() {
        case .loaded(let items), .stale(let items):
            news = .success(items)
        case .notFound, .unparsable:
            news = .failure(.couldNotLoadFromFile)
        }
    }
}
