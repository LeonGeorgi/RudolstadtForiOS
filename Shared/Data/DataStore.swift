import BackgroundTasks
import Foundation
import SwiftUI

extension StringProtocol {
    func nilIfEmpty() -> Self? {
        return self.isEmpty ? nil : self
    }
}

final class DataStore: ObservableObject {

    @Published var data: LoadingEntity<FestivalData> = .loading
    @Published var news: LoadingEntity<[NewsItem]> = .loading
    @Published var recommendedEvents: [Int]? = nil
    @Published var estimatedEventDurations: [Int: Int]? = nil
    @Published var artistLinks: [String: ArtistLinks]? = nil
    
    var extraData: ExtraDataCollection? = nil

    static let year = 2025

    let dataLoader: DataLoader
    let apiClient: APIClient

    let cacheUrl: URL

    init() {
        cacheUrl = try! FileManager.default.url(
            for: .cachesDirectory,
            in: .allDomainsMask,
            appropriateFor: nil,
            create: false
        )
        dataLoader = DataLoader(cacheUrl: cacheUrl)
        apiClient = APIClient()
    }

    func loadArtistLinks() {
        print("Parsing artist links")
        let links = parseArtistLinks()
        DispatchQueue.main.async {
            self.artistLinks = links
            print("Published artist links")
        }
    }

    func estimateEventDurations() {
        guard case .success(let entities) = data else {
            return
        }
        let reversedEvents = entities.events.sorted { e1, e2 in
            e1.date > e2.date
        }
        let reversedEventsByStage = Dictionary(grouping: reversedEvents) {
            event in
            event.stage.id
        }
        var eventDurations = [Int: Int]()

        for (_, reversedEventsForStage) in reversedEventsByStage {
            var subsequentEvent: Event? = nil
            for currentEvent in reversedEventsForStage {
                var length: Int = 60
                if let subsequentEvent = subsequentEvent {
                    let minutesUntilNextEvent =
                        subsequentEvent.date.timeIntervalSince(
                            currentEvent.date
                        ) / 60
                    let minutesUntilNextEventRoundedDown =
                        floor((minutesUntilNextEvent) / 30.0) * 30
                    if minutesUntilNextEventRoundedDown < 30 {
                        length = Int(minutesUntilNextEvent)
                    } else if minutesUntilNextEventRoundedDown < 60 {
                        length = Int(minutesUntilNextEventRoundedDown)
                    } else {
                        let halfWayTimeInterval =
                            floor((minutesUntilNextEvent / 2) / 30.0) * 30
                        if halfWayTimeInterval < 30 {
                            length = Int(halfWayTimeInterval)
                        } else if halfWayTimeInterval <= 90 {
                            length = Int(halfWayTimeInterval)
                        } else if minutesUntilNextEvent > 300 {
                            length = 60
                        } else {
                            length = 90
                        }

                    }
                }
                eventDurations[currentEvent.id] = length
                subsequentEvent = currentEvent
            }
        }
        print("Calculated event durations")
        DispatchQueue.main.async {
            self.estimatedEventDurations = eventDurations
            print("Published event durations")
        }

    }

    func updateRecommentations(savedEventsIds: [Int], ratings: [String: Int]) {
        if case .success(let entities) = data {
            let generator = ScheduleGenerator2(
                allEvents: entities.events,
                storedEventIds: savedEventsIds,
                allArtists: entities.artists,
                artistRatings: ratings,
                eventDurations: estimatedEventDurations
            )
            let recommendations = generator.generateRecommendations()
            DispatchQueue.main.async {
                self.recommendedEvents = recommendations
            }
        }

    }

    func loadData() async {
        DispatchQueue.main.async {
            if case .success = self.data {
                // nothing to do
            } else {
                self.data = .loading
            }
        }
        loadExtraData()
        print("Checking if files are up to date")
        let (filesUpToDate, resultFromCache) =
            loadAndSetDataFromFilesIfUpToDate()
        if filesUpToDate {
            print("Files are up to date, skipping redownload")
        } else {
            print("Files are out of date, redownloading")
            await downloadAndSetData(resultFromCache: resultFromCache)
        }
    }
    
    func loadExtraData() {
        let extraData = loadExtraDataFromResource(fileName: "extra_data")
        self.extraData = extraData
    }

    func loadNews() async {
        if case .success(let news) = self.news {
            // nothing to do, news is already loaded
        } else {
            DispatchQueue.main.async {
                self.news = .loading
            }
        }
        let loadedNews = dataLoader.loadNewsFromFile()
        if case .loaded(let news) = loadedNews {
            DispatchQueue.main.async {
                self.news = .success(news)
            }
        } else {
            await updateAndLoadNews()
        }
    }

    private func downloadAndSetData(
        resultFromCache: FileLoadingResult<FestivalData>
    ) async {
        DispatchQueue.main.async {
            if case .tooOld(let loadedData) = resultFromCache {
                self.data = .success(loadedData)
            }
        }
        let apiData = try? await apiClient.fetchFestivalData()
        guard let apiData else {
            print("Download failed")
            setDataAfterFailedDownload(resultFromCache: resultFromCache)
            return
        }
        let storedFile = dataLoader.storeAPIRudolstadtDataToFile(
            data: apiData,
            fileName: "rudolstadt_data.json"
        )
        if !storedFile {
            print("Could not store API data to file")
        }
        let entities = convertAPIRudolstadtDataToEntities(apiData: apiData, extraData: extraData ?? ExtraDataCollection.empty())
        setDataAfterSuccessfulDownload(
            resultFromDownload: .loaded(entities),
            resultFromCache: resultFromCache
        )
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
        DispatchQueue.main.async {
            self.data = .success(loadedData)
        }
        return (true, resultFromCache)
    }

    private func setDataAfterFailedDownload(
        resultFromCache: FileLoadingResult<FestivalData>
    ) {
        DispatchQueue.main.async {
            if case .tooOld(let loadedData) = resultFromCache {
                self.data = .success(loadedData)
            } else {
                self.data = .failure(.apiNotResponding)
            }
        }
    }

    private func setDataAfterSuccessfulDownload(
        resultFromDownload: FileLoadingResult<FestivalData>,
        resultFromCache: FileLoadingResult<FestivalData>
    ) {
        DispatchQueue.main.async {
            switch resultFromDownload {
            case .loaded(let loadedData):
                self.data = .success(loadedData)
            case .tooOld(let loadedData):
                self.data = .success(loadedData)
            default:
                if case .tooOld(let loadedData) = resultFromCache {
                    self.data = .success(loadedData)
                } else {
                    self.data = .failure(.couldNotLoadFromFile)
                }
            }
        }
    }

    func updateAndLoadNewsIfNecessary() async {
        if shouldNewsBeUpdated() {
            await updateAndLoadNews()
        } else {
            print("News file is from last 10 minutes")
        }
    }

    private func updateAndLoadNews() async {
        let apiNews = try? await apiClient.fetchNews()
        guard let apiNews = apiNews else {
            print("Could not load news from API")
            return
        }
        let storedFile = dataLoader.storeAPINewsToFile(
            news: apiNews,
            fileName: "news.json"
        )
        if !storedFile {
            print("Could not store news to file")
        }

        UserSettings().oldNews = apiNews.map { apiNewsItem in
            apiNewsItem.id
        }

        DispatchQueue.main.async {
            self.news = .success(apiNews.map(convertAPINewsItemToNewsItem))
            print("Updated news data")
        }

    }

    private func shouldNewsBeUpdated() -> Swift.Bool {
        let someTimeAgo = Calendar.current.date(
            byAdding: .minute,
            value: 10,
            to: Date.now
        )
        return !dataLoader.isFileOlderThan(
            fileName: "news.json",
            date: someTimeAgo
        )
    }

    private func sendNewsNotification() {
        let fileNews = dataLoader.loadNewsFromFile()
        let settings = UserSettings()
        let oldNewsIds = settings.oldNews
        let content = UNMutableNotificationContent()
        content.title = "Downloaded news"
        content.subtitle = "Sending notifications"
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 5,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
        /*
        for newsItem in news {
            if !newsItem.isInCurrentLanguage || oldNewsIds.contains(newsItem.id)
            {
                continue
            }
            let content = UNMutableNotificationContent()
            content.title = newsItem.shortDescription
            content.subtitle = newsItem.formattedLongDescription
            content.sound = UNNotificationSound.default
        
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: 5,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: String(newsItem.id),
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
        settings.oldNews = news.map { newsItem in
            newsItem.id
        }*/
    }
}

struct FileNotFoundError: Error {

}
