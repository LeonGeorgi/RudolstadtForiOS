//
//  DataProvider.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import Foundation
import SwiftUI

extension StringProtocol {
    func nilIfEmpty() -> Self? {
        return self.isEmpty ? nil : self
    }
}

extension Artist {
    var thumbImage: Image {
        get {
            return DataProvider.createImage(artist: self, directoryName: "thumbs")
        }
    }

    var fullImage: Image {
        get {
            return DataProvider.createImage(artist: self, directoryName: "full")
        }
    }
}

final class DataProvider: ObservableObject {

    @Published var data: FestivalData = .empty

    func loadData() {
        let artists = DataProvider.readArtistsFromFile()
        let areas = DataProvider.readAreasFromFile()
        let stages = DataProvider.readStagesFromFile(areas: areas)
        let tags = DataProvider.readTagsFromFile()
        let events = DataProvider.readEventsFromFile(stages: stages, artists: artists, tags: tags)
        let news = DataProvider.readNewsFromFile()

        data = FestivalData(artists: artists, areas: areas, events: events, news: news, stages: stages, tags: tags)

//        DataUpdater.updateData {
//
//            let loadedArtists = DataProvider.readArtistsFromFile()
//            let loadedAreas = DataProvider.readAreasFromFile()
//            let loadedStages = DataProvider.readStagesFromFile(areas: loadedAreas)
//            let loadedTags = DataProvider.readTagsFromFile()
//            let loadedEvents = DataProvider.readEventsFromFile(stages: loadedStages, artists: loadedArtists, tags: loadedTags)
//            DispatchQueue.main.async {
//                self.artists = loadedArtists
//                self.events = loadedEvents
//            }
//        }
    }

    static func readLinesFromFile(named fileName: String) -> [Substring.SubSequence] {
        let dataFile = DataUpdater.cacheUrl.appendingPathComponent(fileName)
        let fileAsString = (try? String(contentsOf: dataFile)) ?? ""
        return fileAsString.split(separator: "\n")
    }

    static func parseInformationFromLine<T: StringProtocol>(_ line: T) -> [T.SubSequence] {
        return line.split(separator: "~", omittingEmptySubsequences: false)
    }

    static func readAreasFromFile() -> [Area] {
        let lines = readLinesFromFile(named: DataUpdater.areasFileName)
        return lines.map { line -> Area in
            let areaInformation = parseInformationFromLine(line)
            return Area(
                    id: Int(areaInformation[0]) ?? -1,
                    germanName: String(areaInformation[1]),
                    englishName: String(areaInformation[2])
            )
        }
    }

    static func readArtistsFromFile() -> [Artist] {
        let lines = readLinesFromFile(named: DataUpdater.artistsFileName)
        let artists: [Artist] = lines.map { line in
            let artistInformation = parseInformationFromLine(line)
            return Artist(
                    id: Int(artistInformation[0]) ?? -1,
                    artistType: ArtistType(rawValue: Int(artistInformation[1]) ?? -1) ?? .stage,
                    someNumber: Int(artistInformation[2]) ?? -1,
                    name: String(artistInformation[3]),
                    countries: String(artistInformation[4]),
                    url: artistInformation[5].nilIfEmpty().map(String.init),
                    facebookID: artistInformation[6].nilIfEmpty().map(String.init),
                    youtubeID: artistInformation[7].nilIfEmpty().map(String.init),
                    imageName: artistInformation[8].nilIfEmpty().map(String.init),
                    descriptionGerman: String(artistInformation[9]),
                    descriptionEnglish: String(artistInformation[10])
            )
        }
        return artists
    }

    static func readStagesFromFile(areas: [Area]) -> [Stage] {
        let lines = readLinesFromFile(named: DataUpdater.stagesFileName)
        return lines.map { line -> Stage in
            let stageInformation = parseInformationFromLine(line)
            let areaId = Int(stageInformation[8]) ?? -1
            let area = areas.first {
                $0.id == areaId
            }!
            return Stage(
                    id: Int(stageInformation[0]) ?? -1,
                    germanName: String(stageInformation[1]),
                    englishName: String(stageInformation[2]),
                    germanDescription: stageInformation[3].nilIfEmpty().map(String.init),
                    englishDescription: stageInformation[4].nilIfEmpty().map(String.init),
                    stageNumber: Int(stageInformation[5]),
                    latitude: Double(stageInformation[6])!,
                    longitude: Double(stageInformation[7])!,
                    area: area,
                    unknownNumber: Int(stageInformation[9])
            )
        }
    }

    static func readEventsFromFile(stages: [Stage], artists: [Artist], tags: [Tag]) -> [Event] {
        let lines = readLinesFromFile(named: DataUpdater.eventsFileName)
        return lines.map { line -> Event in
            let eventInformation = parseInformationFromLine(line)
            let stageId = Int(eventInformation[3]) ?? -1
            let stage = stages.first {
                $0.id == stageId
            }!

            let artistId = Int(eventInformation[4]) ?? -1
            let artist = artists.first {
                $0.id == artistId
            }!

            let tagId = Int(eventInformation[5]) ?? -1
            let tag = tags.first {
                $0.id == tagId
            }
            return Event(
                    id: Int(eventInformation[0]) ?? -1,
                    dayInJuly: Int(eventInformation[1]) ?? -1,
                    timeAsString: String(eventInformation[2]),
                    stage: stage,
                    artist: artist,
                    tag: tag
            )
        }
    }

    static func readTagsFromFile() -> [Tag] {
        let lines = readLinesFromFile(named: DataUpdater.tagsFileName)
        return lines.map { line -> Tag in
            let tagInformation = parseInformationFromLine(line)
            return Tag(
                    id: Int(tagInformation[0]) ?? -1,
                    germanName: String(tagInformation[1]),
                    englishName: String(tagInformation[2])
            )
        }
    }

    static func readNewsFromFile() -> [NewsItem] {
        let lines: [Substring.SubSequence] = readLinesFromFile(named: DataUpdater.newsFileName)
        return lines.map { (line: Substring.SubSequence) -> NewsItem in
            let newsInformation = parseInformationFromLine(line)
            return NewsItem(
                    id: Int(newsInformation[0]) ?? -1,
                    languageCode: String(newsInformation[1]),
                    dateAsString: String(newsInformation[2]),
                    timeAsString: String(newsInformation[3]),
                    shortDescription: String(newsInformation[4]),
                    longDescription: String(newsInformation[5]),
                    content: String(newsInformation[6])
            )
        }
    }

    static func createImage(artist: Artist, directoryName: String) -> Image {

        let placeholder = Image("placeholder")

        guard  let imageName = artist.imageName else {
            return placeholder
        }

        do {
            let data = try Data(contentsOf: DataUpdater.cacheUrl.appendingPathComponent(directoryName).appendingPathComponent(imageName))

            if let uiImage = UIImage(data: data) {
                return Image(uiImage: uiImage)
            } else {
                return placeholder
            }

        } catch {
            return placeholder
        }
    }
}
