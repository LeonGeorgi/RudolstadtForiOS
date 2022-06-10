//
//  DataUpdater.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import Foundation

class DataUpdater {

    static let newsFileName = "news.dat"
    static let areasFileName = "areas.dat"
    static let artistsFileName = "artists.dat"
    static let eventsFileName = "events.dat"
    static let stagesFileName = "stages.dat"
    static let tagsFileName = "tags.dat"

    static let useApiImageUrl = true
    static let year = DataStore.year
    static let thumbUrl = getThumbUrl(year: year)
    static let fullImageUrl = getFullUrl(year: year)
    static let streetMusicThumbUrl = getStreetMusicThumbUrl(year: year)
    static let streetMusicFullUrl = getStreetMusicFullUrl(year: year)

    static let cacheUrl = try! FileManager.default.url(for: .cachesDirectory, in: .allDomainsMask, appropriateFor: nil, create: false) // TODO
    
    static func getThumbUrl(year: Int) -> String {
        if year >= 2022 && !useApiImageUrl {
            return "https://www.rudolstadt-festival.de/files/Bilder/\(year)/Artists/Thumbs"
        }
        return "https://rudolstadt-festival.de/data/\(year)/images/thumbs"
    }
    
    static func getFullUrl(year: Int) -> String {
        if year >= 2022 && !useApiImageUrl {
            return "https://www.rudolstadt-festival.de/files/Bilder/\(year)/Artists/Thumbs"
        }
        return "https://rudolstadt-festival.de/data/\(year)/images/full"
    }
    
    static func getStreetMusicThumbUrl(year: Int) -> String {
        if year >= 2022 && !useApiImageUrl {
            return "https://www.rudolstadt-festival.de/files/Bilder/\(year)/Stramu"
        }
        return "https://rudolstadt-festival.de/data/\(year)/images/full"
    }
    
    static func getStreetMusicFullUrl(year: Int) -> String {
        if year >= 2022 && !useApiImageUrl {
            return "https://www.rudolstadt-festival.de/files/Bilder/\(year)/Stramu"
        }
        return "https://rudolstadt-festival.de/data/\(year)/images/full"
    }
    
    
    static func downloadAllDataToFiles(onFinish: @escaping (DownloadResult) -> Void) {
        let baseUrl = "https://rudolstadt-festival.de/data"
        let fileNames = Set([newsFileName, areasFileName, artistsFileName, eventsFileName, stagesFileName, tagsFileName])
        var downloadedFileNames: Set<String> = Set()
        var finalResult = DownloadResult.success
        for fileName in fileNames {
            if let url = URL(string: "\(baseUrl)/\(year)/\(fileName)") {
                downloadFile(url: url, destination: cacheUrl.appendingPathComponent("\(DataStore.year)_\(fileName)")) { downloadResult in
                    if case DownloadResult.failure = downloadResult {
                        finalResult = downloadResult
                    }
                    downloadedFileNames.insert(fileName)
                    if downloadedFileNames == fileNames {
                        print("Downloaded all files")
                        DispatchQueue.main.async {
                            onFinish(finalResult)
                        }
                    }
                }
            }
        }
    }

    static func downloadFile(url: URL, destination: URL, overwrite: Bool = true, onFinish: @escaping (DownloadResult) -> Void) {
        print("Downloading from \(url)")

        let task = URLSession.shared.downloadTask(with: url) { (location, response, error) in
            guard let fileLocation = location else {
                onFinish(.failure(.downloadError))
                return
            }
            if (overwrite) {
                try? FileManager.default.removeItem(atPath: destination.path)
            }
            do {
                try FileManager.default.moveItem(atPath: fileLocation.path, toPath: destination.path)
                onFinish(.success)
            } catch {
                onFinish(.failure(.unableToSave))
            }

        }
        task.resume()
    }
}
