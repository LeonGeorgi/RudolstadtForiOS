//
//  DataUpdater.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import Foundation

class DataUpdater {
    let files: DataFiles
    let cacheUrl: URL

    init(files: DataFiles, cacheUrl: URL) {
        self.files = files
        self.cacheUrl = cacheUrl
    }

    func downloadAllDataToFiles() async -> DownloadResult {
        let fileNames = Set([files.news, files.areas, files.artists, files.events, files.stages, files.tags])
        var finalResult = DownloadResult.success
        for fileName in fileNames {
            guard let url = URL(string: generateUrl(fileName: fileName)) else {
                finalResult = DownloadResult.failure(.downloadError)
                continue
            }
            let downloadResult = await downloadFile(url: url, destination: getCacheUri(for: fileName))
            if case .failure = downloadResult {
                finalResult = downloadResult
            }

        }
        return finalResult
    }

    func getCacheUri(for fileName: String) -> URL {
        cacheUrl.appendingPathComponent("\(DataStore.year)_\(fileName)")
    }

    func generateUrl(fileName: String) -> String {
        let baseUrl = "https://rudolstadt-festival.de/data"
        return "\(baseUrl)/\(DataStore.year)/\(fileName)"
    }

    func downloadFile(url: URL, destination: URL, overwrite: Bool = true) async -> DownloadResult {
        print("Downloading from \(url)")

        let result: DownloadResult = await withCheckedContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: url) { (location, response, error) in
                guard let fileLocation = location else {
                    continuation.resume(returning: .failure(.downloadError))
                    return
                }
                if (overwrite) {
                    try? FileManager.default.removeItem(atPath: destination.path)
                }
                do {
                    try FileManager.default.moveItem(atPath: fileLocation.path, toPath: destination.path)
                    continuation.resume(returning: .success)
                } catch {
                    continuation.resume(returning: .failure(.unableToSave))
                }
            }
            task.resume()
        }
        return result
    }
}
