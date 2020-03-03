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

    static let year = "2018"
    static let thumbUrl = "https://rudolstadt-festival.de/data/\(year)/images/thumbs"
    static let fullImageUrl = "https://rudolstadt-festival.de/data/\(year)/images/full"

    static let cacheUrl = try! FileManager.default.url(for: .cachesDirectory, in: .allDomainsMask, appropriateFor: nil, create: false) // TODO

    static func updateData(onUpdate: @escaping () -> ()) {
        let baseUrl = "https://rudolstadt-festival.de/data"
        let fileNames = [newsFileName, areasFileName, artistsFileName, eventsFileName, stagesFileName, tagsFileName]
        return;
        DispatchQueue.global().async {
            for fileName in fileNames {
                if let url = URL(string: "\(baseUrl)/\(year)/\(fileName)") {
                    print(url)
                    downloadFile(url: url, destination: cacheUrl.appendingPathComponent(fileName))
                }
            }
            onUpdate()
        }
    }

    static func updateThumbnails() {
        downloadArtistImages(
                baseUrl: "https://rudolstadt-festival.de/data/\(year)/images/thumbs",
                destinationFolder: cacheUrl.appendingPathComponent("thumbs")
        )
    }

    static func updateFullImages() {
        downloadArtistImages(
                baseUrl: "https://rudolstadt-festival.de/data/\(year)/images/full",
                destinationFolder: cacheUrl.appendingPathComponent("full")
        )
    }

    static func downloadArtistImages(baseUrl: String, destinationFolder: URL) {
        do {
            try FileManager.default.removeItem(atPath: destinationFolder.path)
        } catch {
            print(error)
        }

        do {
            try FileManager.default.createDirectory(atPath: destinationFolder.path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
        }


        let artists = DataStore.readArtistsFromFile()
        for artist in artists {
            guard let imageName = artist.imageName else {
                print("Artist \(artist.name) has no imageName.")
                continue
            }

            guard let url = URL(string: "\(baseUrl)/\(imageName)") else {
                print("Cannot download image for artist \(artist.name)")
                continue
            }
            downloadFile(url: url, destination: destinationFolder.appendingPathComponent(imageName))
        }


        do {
            print(try FileManager.default.contentsOfDirectory(atPath: cacheUrl.path))
            print(try FileManager.default.contentsOfDirectory(atPath: destinationFolder.path))

        } catch {
            print(error)
        }

    }

    static func downloadFile(url: URL, destination: URL, overwrite: Bool = true) -> Bool {
        print("Downloading from \(url)")
        var success = false

        let task = URLSession.shared.downloadTask(with: url) { (location, response, error) in
            guard let fileLocation = location else {
                return
            }
            if (overwrite) {
                try? FileManager.default.removeItem(atPath: destination.path)
            }
            do {
                try FileManager.default.moveItem(atPath: fileLocation.path, toPath: destination.path)
                success = true
            } catch {
                print(error)
            }

        }
        task.resume()
        return success
    }
}
