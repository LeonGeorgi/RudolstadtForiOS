//
//  DataProvider.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import Foundation
import SwiftUI
import BackgroundTasks

extension StringProtocol {
    func nilIfEmpty() -> Self? {
        return self.isEmpty ? nil : self
    }
}

final class DataStore: ObservableObject {

    @Published var data: LoadingEntity<Entities> = .loading
    @Published var recommendedEvents: [Int]? = nil
    static let year = 2022

    let files: DataFiles
    let dataLoader: DataLoader
    let dataUpdater: DataUpdater

    let cacheUrl: URL

    init() {
        files = DataFiles(
                news: "news.dat",
                areas: "areas.dat",
                artists: "artists.dat",
                events: "events.dat",
                stages: "stages.dat",
                tags: "tags.dat"
        )
        cacheUrl = try! FileManager.default.url(for: .cachesDirectory, in: .allDomainsMask, appropriateFor: nil, create: false)
        dataLoader = DataLoader(files: files, cacheUrl: cacheUrl)
        dataUpdater = DataUpdater(files: files, cacheUrl: cacheUrl)

    }
    
    func updateRecommentations(savedEventsIds: [Int], ratings: Dictionary<String, Int>) {
        if case .success(let entities) = data {
            let generator = ScheduleGenerator2(allEvents: entities.events, storedEventIds: savedEventsIds, allArtists: entities.artists, artistRatings: ratings)
            let recommendations = generator.generateRecommendations()
            DispatchQueue.main.async {
                self.recommendedEvents = recommendations
            }
        }
        
    }

    func loadData() async {
        data = .loading
        let (filesUpToDate, resultFromCache) = loadAndSetDataFromFilesIfUpToDate()
        if !filesUpToDate {
            await downloadAndSetData(resultFromCache: resultFromCache)
        }
        
        if case .success(let entities) = data {
            UserSettings().oldNews = entities.news.map { newsItem in
                newsItem.id
            }
        }
    }

    private func downloadAndSetData(resultFromCache: FileLoadingResult<Entities>) async {
        let downloadResult = await dataUpdater.downloadAllDataToFiles()
        if case DownloadResult.success = downloadResult {
            let resultFromDownload = dataLoader.loadEntitiesFromFiles()
            setDataAfterSuccessfulDownload(resultFromDownload: resultFromDownload, resultFromCache: resultFromCache)
        } else {
            setDataAfterFailedDownload(resultFromCache: resultFromCache)
        }
    }

    func loadAndSetDataFromFilesIfUpToDate() -> (Bool, FileLoadingResult<Entities>) {
        let resultFromCache = dataLoader.loadEntitiesFromFiles()
        guard case .loaded(let loadedData) = resultFromCache else {
            return (false, resultFromCache)
        }
        data = .success(loadedData)
        return (true, resultFromCache)
    }

    private func setDataAfterFailedDownload(resultFromCache: FileLoadingResult<Entities>) {
        DispatchQueue.main.async {
            if case .tooOld(let loadedData) = resultFromCache {
                self.data = .success(loadedData)
            } else {
                self.data = .failure(.apiNotResponding)
            }
        }
    }

    private func setDataAfterSuccessfulDownload(resultFromDownload: FileLoadingResult<Entities>, resultFromCache: FileLoadingResult<Entities>) {
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
        let downloadResult = await downloadNews()
        print("Update news resulted in", downloadResult)
        if case .success = downloadResult {
            reloadNews()
        }


    }

    private func reloadNews() {
        do {
            let (news, _) = try dataLoader.readEntitiesFromFile(fileName: files.news, converter: dataLoader.convertLineToNewsItem)
            updateNewsEntities(news: news)
        } catch {
            print("Could not load news \(error)")
        }
    }

    private func updateNewsEntities(news: [NewsItem]) {
        if case .success(let entities) = data {
            DispatchQueue.main.async {
                self.data = .success(Entities(
                        artists: entities.artists,
                        areas: entities.areas,
                        stages: entities.stages,
                        events: entities.events,
                        news: news
                ))
                print("Updated news data")
            }
        }
    }

    private func downloadNews() async -> DownloadResult {
        guard let newsUrl = URL(string: dataUpdater.generateUrl(fileName: files.news)) else {
            return .failure(.downloadError)
        }
        let downloadResult = await dataUpdater.downloadFile(url: newsUrl, destination: dataUpdater.getCacheUri(for: files.news))
        return downloadResult
    }

    private func shouldNewsBeUpdated() -> Swift.Bool {
        let someTimeAgo = Calendar.current.date(byAdding: .minute, value: 10, to: Date.now)
        return !dataLoader.isFileOlderThan(fileName: files.news, date: someTimeAgo)
    }

    func setupUpdateNewsTask() {
        registerUpdateNewsTask()
        scheduleUpdateNewsTask()
    }

    private func registerUpdateNewsTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "de.leongeorgi.RudolstadtForiOS.news.refresh", using: nil) { task in
            self.executeUpdateNewsTask(task: task as! BGAppRefreshTask)
        }
    }

    private func executeUpdateNewsTask(task: BGAppRefreshTask) {
        if shouldNewsBeUpdated() {
            scheduleUpdateNewsTask()
            Task {
                let result = await downloadNews()
                switch result {
                case .success:
                    sendNewsNotification()
                    task.setTaskCompleted(success: true)
                case .failure:
                    task.setTaskCompleted(success: false)
                }
            }
        }
    }
    
    private func sendNewsNotification() {
        let news = dataLoader.readNewsFromFile()
        let settings = UserSettings()
        let oldNewsIds = settings.oldNews
        let content = UNMutableNotificationContent()
        content.title = "Downloaded news"
        content.subtitle = "Sending notifications"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
        for newsItem in news {
            if !newsItem.isInCurrentLanguage || oldNewsIds.contains(newsItem.id) {
                continue
            }
            let content = UNMutableNotificationContent()
            content.title = newsItem.shortDescription
            content.subtitle = newsItem.formattedLongDescription
            content.sound = UNNotificationSound.default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(identifier: String(newsItem.id), content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
        settings.oldNews = news.map { newsItem in
            newsItem.id
        }
    }

    private func scheduleUpdateNewsTask() {
        let request = BGAppRefreshTaskRequest(identifier: "de.leongeorgi.RudolstadtForiOS.news.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Scheduled news refresh")
        } catch {
            print("Could not schedule news refresh: \(error)")
        }
    }
}

struct FileNotFoundError: Error {

}
