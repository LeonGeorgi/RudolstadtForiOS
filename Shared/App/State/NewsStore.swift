import Combine
import Foundation

@MainActor
final class NewsStore: ObservableObject {
    @Published private(set) var news: LoadingEntity<[NewsItem]> = .loading

    private let service: NewsService
    private let bundledNewsLoader: any BundledNewsLoading

    init(service: NewsService, bundledNewsLoader: any BundledNewsLoading) {
        self.service = service
        self.bundledNewsLoader = bundledNewsLoader
    }

    func loadCachedNewsIfAvailable() {
        if let cachedNews = service.loadCachedNews() {
            news = .success(cachedNews)
        }
    }

    func refreshNewsIfNecessary() async {
        guard !ScreenshotRuntime.isEnabled else {
            return
        }
        news = LoadingEntity(from: await service.refreshNewsIfNecessary())
    }

    func loadBundledScreenshotData() {
        switch bundledNewsLoader.loadBundledNewsBackup() {
        case .loaded(let items), .stale(let items):
            news = .success(items)
        case .notFound, .unparsable:
            news = .failure(.couldNotLoadFromFile)
        }
    }
}
