//
// Created by Leon Georgi on 12.06.22.
//

import Foundation

class DataLoader {
    let files: DataFiles
    let cacheUrl: URL

    init(files: DataFiles, cacheUrl: URL) {
        self.files = files
        self.cacheUrl = cacheUrl
    }

    func loadEntitiesFromFiles() -> FileLoadingResult<Entities> {

        do {
            let (allFilesUpToDate, entities) = try readEntitiesFromFiles()
            if allFilesUpToDate {
                return .loaded(entities)
            }
            return .tooOld(entities)
        } catch is FileNotFoundError {
            return .notFound
        } catch {
            return .unparsable
        }
    }

    private func readEntitiesFromFiles() throws -> (Swift.Bool, Entities) {
        let (areas, areasTooOld) = try readEntitiesFromFile(fileName: files.areas, converter: convertLineToArea)
        let (artists, artistsTooOld) = try readEntitiesFromFile(fileName: files.artists, converter: convertLineToArtist)
        let (stages, stagesTooOld) = try readEntitiesFromFile(fileName: files.stages) { information in
            convertLineToStage(information: information, areas: areas)
        }
        let (tags, tagsTooOld) = try readEntitiesFromFile(fileName: files.tags, converter: convertLineToTag)
        let (events, eventsTooOld) = try readEntitiesFromFile(fileName: files.events) { information in
            convertLineToEvent(information: information, stages: stages, artists: artists, tags: tags)
        }
        let (news, newsTooOld) = try readEntitiesFromFile(fileName: files.news, converter: convertLineToNewsItem)

        let entities = Entities(artists: artists, areas: areas, stages: stages, events: events, news: news)
        let allFilesUpToDate = !areasTooOld && !artistsTooOld && !stagesTooOld && !tagsTooOld && !eventsTooOld && !newsTooOld
        return (allFilesUpToDate, entities)
    }
    
    func readNewsFromFile() -> [NewsItem] {
        do {
            let (news, _) = try readEntitiesFromFile(fileName: files.news, converter: convertLineToNewsItem)
            return news
        } catch {
            return []
        }
    }

    func convertLineToArtist(information: [Substring.SubSequence]) -> Artist {
        Artist(
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
                stageType: StageType(rawValue: Int(information[9]) ?? -1) ?? .unknown
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
        Tag(
                id: Int(information[0]) ?? -1,
                germanName: String(information[1]),
                englishName: String(information[2])
        )
    }

    func convertLineToNewsItem(information: [Substring.SubSequence]) -> NewsItem {
        NewsItem(
                id: Int(information[0]) ?? -1,
                languageCode: String(information[1]),
                dateAsString: String(information[2]),
                timeAsString: String(information[3]),
                shortDescription: String(information[4]),
                longDescription: String(information[5]),
                content: String(information[6])
        )
    }


    func readEntitiesFromFile<T>(fileName: String, converter: ([Substring.SubSequence]) -> T?) throws -> ([T], Bool) {
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

    func isFileTooOld(fileName: String) -> Bool {
        let someTimeAgo = Calendar.current.date(byAdding: .hour, value: -6, to: Date.now)
        return isFileOlderThan(fileName: fileName, date: someTimeAgo)
    }



    func getCacheUri(for fileName: String) -> URL {
        cacheUrl.appendingPathComponent("\(DataStore.year)_\(fileName)")
    }

    func isFileOlderThan(fileName: String, date: Date?) -> Bool {
        let dataFile = getCacheUri(for: fileName)

        do {
            let attr = try FileManager.default.attributesOfItem(atPath: dataFile.path)
            guard let modificationDate = attr[FileAttributeKey.modificationDate] as? Date else {
                return false
            }
            if let someTimeAgo = date {
                return modificationDate < someTimeAgo
            }
            return Calendar.current.compare(modificationDate, to: .now, toGranularity: .day) == .orderedAscending
        } catch {
            return false
        }
    }

    func readLinesFromFile(named fileName: String) -> Result<[Substring.SubSequence], Error> {
        let dataFile = getCacheUri(for: fileName)

        do {
            let fileAsString = try String(contentsOf: dataFile)
            return Result.success(fileAsString.split(separator: "\n"))
        } catch let error {
            return Result.failure(error)
        }
    }

    func parseInformationFromLine<T: StringProtocol>(_ line: T) -> [T.SubSequence] {
        line.split(separator: "~", omittingEmptySubsequences: false)
    }
}

struct DataFiles {
    let news: String
    let areas: String
    let artists: String
    let events: String
    let stages: String
    let tags: String
}
