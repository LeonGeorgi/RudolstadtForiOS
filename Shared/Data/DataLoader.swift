import Foundation

class DataLoader {
    let cacheUrl: URL

    init(cacheUrl: URL) {
        self.cacheUrl = cacheUrl
    }

    func loadEntitiesFromFile(extraData: ExtraDataCollection) -> FileLoadingResult<FestivalData> {
        let (apiData, tooOld) = readAPIRudolstadtDataFromFile(
            fileName: "rudolstadt_data.json"
        )
        guard let apiData else {
            return .notFound
        }
        let entities = convertAPIRudolstadtDataToEntities(apiData: apiData, extraData: extraData)
        if tooOld {
            return .tooOld(entities)
        }
        return .loaded(entities)
    }

    func loadNewsFromFile() -> FileLoadingResult<[NewsItem]> {
        let (news, tooOld) = readAPINewsFromFile(fileName: "news.json")
        print("Loaded \(news?.count ?? 0) news items from file")
        guard let news else {
            return .notFound
        }
        let newsItems = news.map(convertAPINewsItemToNewsItem)
        if tooOld {
            return .tooOld(newsItems)
        }
        return .loaded(newsItems)
    }

    func storeAPIRudolstadtDataToFile(data: APIRudolstadtData, fileName: String)
        -> Bool
    {
        let dataFile = getCacheUri(for: fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: dataFile)
        } catch {
            print("Error writing to file \(dataFile): \(error)")
        }
        return FileManager.default.fileExists(atPath: dataFile.path)
    }
    
    func storeAPINewsToFile(news: [APINewsItem], fileName: String) -> Bool {
        let dataFile = getCacheUri(for: fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let jsonData = try encoder.encode(news)
            try jsonData.write(to: dataFile)
        } catch {
            print("Error writing to file \(dataFile): \(error)")
        }
        return FileManager.default.fileExists(atPath: dataFile.path)
    }

    func readAPIRudolstadtDataFromFile(fileName: String) -> (
        APIRudolstadtData?, Bool
    ) {
        let tooOld = isFileTooOld(fileName: fileName)
        let dataFile = getCacheUri(for: fileName)

        do {
            let data = try Data(contentsOf: dataFile)
            let decoder = JSONDecoder()
            let apiData = try decoder.decode(APIRudolstadtData.self, from: data)
            return (apiData, tooOld)
        } catch {
            print("Error reading or decoding file \(dataFile): \(error)")
            return (nil, tooOld)
        }
    }

    func readAPINewsFromFile(fileName: String) -> ([APINewsItem]?, Bool) {
        let tooOld = isFileTooOld(fileName: fileName)
        let dataFile = getCacheUri(for: fileName)

        do {
            let data = try Data(contentsOf: dataFile)
            let decoder = JSONDecoder()
            let apiData = try decoder.decode([APINewsItem].self, from: data)
            return (apiData, tooOld)
        } catch {
            print("Error reading or decoding file \(dataFile): \(error)")
            return (nil, tooOld)
        }
    }

    func isFileTooOld(fileName: String) -> Bool {
        let someTimeAgo = Calendar.current.date(
            byAdding: .hour,
            value: -3,
            to: Date.now
        )
        return isFileOlderThan(fileName: fileName, date: someTimeAgo)
    }

    func getCacheUri(for fileName: String) -> URL {
        cacheUrl.appendingPathComponent("\(DataStore.year)_\(fileName)")
    }

    func isFileOlderThan(fileName: String, date: Date?) -> Bool {
        let dataFile = getCacheUri(for: fileName)

        do {
            let attr = try FileManager.default.attributesOfItem(
                atPath: dataFile.path
            )
            guard
                let modificationDate = attr[FileAttributeKey.modificationDate]
                    as? Date
            else {
                return false
            }
            print("Modification date for \(fileName): \(modificationDate)")
            if let someTimeAgo = date {
                return modificationDate < someTimeAgo
            }
            return Calendar.current.compare(
                modificationDate,
                to: .now,
                toGranularity: .day
            ) == .orderedAscending
        } catch {
            return false
        }
    }
}
