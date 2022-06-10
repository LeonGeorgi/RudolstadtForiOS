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
            DataStore.createImage(artist: self, directoryName: "thumbs")
        }
    }
    
    var fullImage: Image {
        get {
            DataStore.createImage(artist: self, directoryName: "full")
        }
    }
}

final class DataStore: ObservableObject {
    
    @Published var data: LoadingEntity<Entities> = .loading
    static let year = 2022
    
    func loadData() {
        
        data = .loading
        let result = loadAllDataFromFiles()
        if case .loaded(let loadedData) = result {
            data = .success(loadedData)
            return
        }
        DataUpdater.downloadAllDataToFiles { (downloadResult: DownloadResult) in
            if case DownloadResult.success = downloadResult {
                let r = self.loadAllDataFromFiles()
                switch r {
                case .loaded(let loadedData):
                    self.data = .success(loadedData)
                case .tooOld(let loadedData):
                    self.data = .success(loadedData)
                default:
                    if case .tooOld(let loadedData) = result {
                        self.data = .success(loadedData)
                    } else {
                        self.data = .failure(.couldNotLoadFromFile)
                    }
                }
            } else {
                if case .tooOld(let loadedData) = result {
                    self.data = .success(loadedData)
                } else {
                    self.data = .failure(.apiNotResponding)
                }
            }
        }
        
    }
    
    func loadAllDataFromFiles() -> FileLoadingResult<Entities> {

        do {
            let (areas, areasTooOld) = try DataStore.readEntitiesFromFile(fileName: DataUpdater.areasFileName, converter: convertLineToArea)
            let (artists, artistsTooOld) = try DataStore.readEntitiesFromFile(fileName: DataUpdater.artistsFileName, converter: convertLineToArtist)
            let (stages, stagesTooOld) = try DataStore.readEntitiesFromFile(fileName: DataUpdater.stagesFileName) { information in
                convertLineToStage(information: information, areas: areas)
            }
            let (tags, tagsTooOld) = try DataStore.readEntitiesFromFile(fileName: DataUpdater.tagsFileName, converter: convertLineToTag)
            let (events, eventsTooOld) = try DataStore.readEntitiesFromFile(fileName: DataUpdater.eventsFileName) { information in
                convertLineToEvent(information: information, stages: stages, artists: artists, tags: tags)
                
            }
            let (news, newsTooOld) = try DataStore.readEntitiesFromFile(fileName: DataUpdater.newsFileName, converter: convertLineToNewsItem)
            
            let entities = Entities(artists: artists, areas: areas, stages: stages, events: events, news: news)
            if !areasTooOld && !artistsTooOld && !stagesTooOld && !tagsTooOld && !eventsTooOld && !newsTooOld {
                return .loaded(entities)
            }
            
            return .tooOld(entities)
        } catch is FileNotFoundError {
            return .notFound
        } catch {
            return .unparsable
        }
    }

    static func isFileTooOld(fileName: String) -> Bool {
        let dataFile = DataUpdater.cacheUrl.appendingPathComponent("\(DataStore.year)_\(fileName)")
        
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: dataFile.path)
            let date = attr[FileAttributeKey.modificationDate] as? Date
            guard let modificationDate = date else {
                return false
            }
            print(modificationDate)
            let now = Date.now
            let someTimeAgo = Calendar.current.date(byAdding: .hour, value: -12, to: now)
            if let someTimeAgo = someTimeAgo {
                return modificationDate < someTimeAgo
            }
            return Calendar.current.compare(modificationDate, to: .now, toGranularity: .day) == .orderedAscending
        } catch {
            return false
        }
    }
    
    static func readLinesFromFile(named fileName: String) -> Result<[Substring.SubSequence], Error> {
        let dataFile = DataUpdater.cacheUrl.appendingPathComponent("\(DataStore.year)_\(fileName)")
        
        do {
            let fileAsString = try String(contentsOf: dataFile)
            return Result.success(fileAsString.split(separator: "\n"))
        } catch let error {
            return Result.failure(error)
        }
    }
    
    static func parseInformationFromLine<T: StringProtocol>(_ line: T) -> [T.SubSequence] {
        line.split(separator: "~", omittingEmptySubsequences: false)
    }
    
    
    static func readEntitiesFromFile<T>(fileName: String, converter: ([Substring.SubSequence]) -> T?) throws -> ([T], Bool) {
        let tooOld = isFileTooOld(fileName: fileName)
        let linesResult = readLinesFromFile(named: fileName)
        switch linesResult {
        case .failure:
            throw FileNotFoundError()
        case .success(let lines):
            let entities = lines.compactMap { line -> T? in
                let information = parseInformationFromLine(line)
                return converter(information)
            }
            return (entities, tooOld)
        }
    }
    
    func convertLineToArtist(information: [Substring.SubSequence]) -> Artist {
        return Artist(
            id: Int(information[0]) ?? -1,
            artistType: ArtistType(rawValue: Int(information[1]) ?? -1) ?? .stage,
            someNumber: Int(information[2]) ?? -1,
            name: String(information[3]),
            countries: String(information[4]),
            url: information[5].nilIfEmpty().map(String.init),
            facebookID: information[6].nilIfEmpty().map(String.init),
            youtubeID: information[7].nilIfEmpty().map(String.init),
            imageName: information[8].nilIfEmpty().map(String.init),
            descriptionGerman: String(information[9]),
            descriptionEnglish: String(information[10])
        )
    }
    
    func convertLineToArea(information: [Substring.SubSequence]) -> Area {
        return Area(
            id: Int(information[0]) ?? -1,
            germanName: String(information[1]),
            englishName: String(information[2])
        )
    }
    
    func convertLineToStage(information: [Substring.SubSequence], areas: [Area]) -> Stage {
        let areaId = Int(information[8]) ?? -1
        let area = areas.first {
            $0.id == areaId
        }!
        return Stage(
            id: Int(information[0]) ?? -1,
            germanName: String(information[1]),
            englishName: String(information[2]),
            germanDescription: information[3].nilIfEmpty().map(String.init),
            englishDescription: information[4].nilIfEmpty().map(String.init),
            stageNumber: Int(information[5]),
            latitude: Double(information[6])!,
            longitude: Double(information[7])!,
            area: area,
            unknownNumber: Int(information[9])
        )
    }
    
    func convertLineToEvent(information: [Substring.SubSequence], stages: [Stage], artists: [Artist], tags: [Tag]) -> Event? {
        let stageId = Int(information[3]) ?? -1
        let stage = stages.first {
            $0.id == stageId
        }!
        
        let artistId = Int(information[4]) ?? -1
        let firstArtist = artists.first {
            $0.id == artistId
        }
        guard let artist = firstArtist else {
            return nil
        }
        
        let tagId = Int(information[5]) ?? -1
        let tag = tags.first {
            $0.id == tagId
        }
        return Event(
            id: Int(information[0]) ?? -1,
            dayInJuly: Int(information[1]) ?? -1,
            timeAsString: String(information[2]),
            stage: stage,
            artist: artist,
            tag: tag
        )
    }
    
    func convertLineToTag(information: [Substring.SubSequence]) -> Tag {
        return Tag(
            id: Int(information[0]) ?? -1,
            germanName: String(information[1]),
            englishName: String(information[2])
        )
    }
    
    func convertLineToNewsItem(information: [Substring.SubSequence]) -> NewsItem {
        return NewsItem(
            id: Int(information[0]) ?? -1,
            languageCode: String(information[1]),
            dateAsString: String(information[2]),
            timeAsString: String(information[3]),
            shortDescription: String(information[4]),
            longDescription: String(information[5]),
            content: String(information[6])
        )
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

struct FileNotFoundError : Error {
    
}
