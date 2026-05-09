import Foundation
import SwiftUI

extension StringProtocol {
    func nilIfEmpty() -> Self? {
        return self.isEmpty ? nil : self
    }
}

@MainActor
final class DataStore: ObservableObject {

    @Published var data: LoadingEntity<FestivalData> = .loading
    @Published var news: LoadingEntity<[NewsItem]> = .loading
    @Published var recommendedEvents: LoadingEntity<[Int]> = .loading
    @Published var estimatedEventDurations: [Int: Int]? = nil
    @Published var artistLinks: [String: ArtistLinks]? = nil
    @Published var browseTaxonomy: [BrowseTaxonomyEntry] = []
    
    var extraData: ExtraDataCollection? = nil
    private var browseTaxonomyByID: [String: BrowseTaxonomyEntry] = [:]

    nonisolated static let year = 2026

    let dataLoader: DataLoader
    let apiClient: APIClient
    let newsService: NewsService
    let recommendationService: RecommendationProviding
    let userSettings: UserSettings

    let cacheUrl: URL

    init(
        userSettings: UserSettings? = nil,
        newsService: NewsService? = nil,
        recommendationService: RecommendationProviding? = nil
    ) {
        let resolvedUserSettings = userSettings ?? UserSettings()
        cacheUrl = try! FileManager.default.url(
            for: .cachesDirectory,
            in: .allDomainsMask,
            appropriateFor: nil,
            create: false
        )
        dataLoader = DataLoader(cacheUrl: cacheUrl)
        apiClient = APIClient()
        self.userSettings = resolvedUserSettings
        self.newsService =
            newsService ?? NewsService(userSettings: resolvedUserSettings)
        self.recommendationService = recommendationService ?? RecommendationService()
    }

    func loadArtistLinks() {
        print("Parsing artist links")
        let links = parseArtistLinks()
        artistLinks = links
        print("Published artist links")
    }

    func refreshRecommendations(now: Date = .now) async {
        guard case .success(let entities) = data else {
            estimatedEventDurations = nil
            recommendedEvents = .loading
            return
        }

        let savedEventIds = userSettings.savedEvents
        let ratings = userSettings.ratings

        recommendedEvents = .loading
        let snapshot = recommendationService.buildSnapshot(
            data: entities,
            savedEventIds: savedEventIds,
            ratings: ratings,
            now: now
        )
        estimatedEventDurations = snapshot.estimatedEventDurations
        recommendedEvents = .success(snapshot.recommendedEventIds)
    }

    func loadData() async {
        if case .success = data {
            // nothing to do
        } else {
            data = .loading
        }
        loadExtraData()
        print("Checking if files are up to date")
        let (filesUpToDate, resultFromCache) = loadAndSetDataFromFilesIfUpToDate()
        if filesUpToDate {
            print("Files are up to date, skipping redownload")
        } else {
            print("Files are out of date, redownloading")
            await downloadAndSetData(resultFromCache: resultFromCache)
        }
    }
    
    func loadExtraData() {
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

    func loadNews() async {
        if case .success = news {
            // nothing to do, news is already loaded
        } else {
            news = .loading
        }
        let result = await newsService.loadNews()
        news = LoadingEntity(from: result)
    }

    func refreshOnAppActive() async {
        print("Trying to load latest app state")
        await loadData()
        loadArtistLinks()
        await loadNews()
        await refreshRecommendations()
    }

    private func downloadAndSetData(
        resultFromCache: FileLoadingResult<FestivalData>
    ) async {
        if case .tooOld(let loadedData) = resultFromCache {
            data = .success(loadedData)
        }
        do {
            let apiData = try await apiClient.fetchFestivalData()
            let storedFile = dataLoader.storeAPIRudolstadtDataToFile(
                data: apiData,
                fileName: "rudolstadt_data.json"
            )
            if !storedFile {
                print("Could not store API data to file")
            }
            let entities = convertAPIRudolstadtDataToEntities(
                apiData: apiData,
                extraData: extraData ?? ExtraDataCollection.empty()
            )
            setDataAfterSuccessfulDownload(
                resultFromDownload: .loaded(entities),
                resultFromCache: resultFromCache
            )
        } catch {
            print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
            print("!!! FESTIVAL DATA DOWNLOAD FAILED")
            print("!!! \(error.localizedDescription)")
            print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
            setDataAfterFailedDownload(resultFromCache: resultFromCache)
        }
    }

    func loadAndSetDataFromFilesIfUpToDate() -> (
        Bool, FileLoadingResult<FestivalData>
    ) {
        let resultFromCache = dataLoader.loadEntitiesFromFile(
            extraData: extraData ?? ExtraDataCollection.empty()
        )
        guard case .loaded(let loadedData) = resultFromCache else {
            return (false, resultFromCache)
        }
        data = .success(loadedData)
        return (true, resultFromCache)
    }

    private func setDataAfterFailedDownload(
        resultFromCache: FileLoadingResult<FestivalData>
    ) {
        if case .tooOld(let loadedData) = resultFromCache {
            data = .success(loadedData)
        } else {
            data = .failure(.apiNotResponding)
        }
    }

    private func setDataAfterSuccessfulDownload(
        resultFromDownload: FileLoadingResult<FestivalData>,
        resultFromCache: FileLoadingResult<FestivalData>
    ) {
        switch resultFromDownload {
        case .loaded(let loadedData):
            data = .success(loadedData)
        case .tooOld(let loadedData):
            data = .success(loadedData)
        default:
            if case .tooOld(let loadedData) = resultFromCache {
                data = .success(loadedData)
            } else {
                data = .failure(.couldNotLoadFromFile)
            }
        }
    }

    func updateAndLoadNewsIfNecessary() async {
        let result = await newsService.refreshNewsIfNecessary()
        news = LoadingEntity(from: result)
    }
}
