import Foundation
import OSLog

private enum CacheReadResult<Value> {
    case loaded(Value, stale: Bool)
    case notFound
    case unparsable
}

final class DataLoader: @unchecked Sendable {
    let cacheURL: URL

    init(cacheURL: URL) {
        self.cacheURL = cacheURL
    }

    func loadFestivalDataFromFile(
        extraData: ExtraDataCollection
    ) -> FileLoadingResult<FestivalData> {
        switch readCachedJSON(
            APIRudolstadtData.self,
            fileName: "rudolstadt_data.json"
        ) {
        case .loaded(let apiData, let stale):
            let entities = convertAPIRudolstadtDataToEntities(
                apiData: apiData,
                extraData: extraData
            )
            return stale ? .stale(entities) : .loaded(entities)
        case .notFound:
            return .notFound
        case .unparsable:
            return .unparsable
        }
    }

    func loadBundledFestivalDataBackup(
        extraData: ExtraDataCollection
    ) -> FileLoadingResult<FestivalData> {
        switch readBundledJSON(
            APIRudolstadtData.self,
            resourceName: "\(DataStore.year)_rudolstadt_data"
        ) {
        case .loaded(let apiData), .stale(let apiData):
            let entities = convertAPIRudolstadtDataToEntities(
                apiData: apiData,
                extraData: extraData
            )
            return .loaded(entities)
        case .notFound:
            return .notFound
        case .unparsable:
            return .unparsable
        }
    }

    func loadNewsFromFile() -> FileLoadingResult<[NewsItem]> {
        switch readCachedJSON([APINewsItem].self, fileName: "news.json") {
        case .loaded(let news, let stale):
            let newsItems = news.map(convertAPINewsItemToNewsItem)
            return stale ? .stale(newsItems) : .loaded(newsItems)
        case .notFound:
            return .notFound
        case .unparsable:
            return .unparsable
        }
    }

    func loadBundledNewsBackup() -> FileLoadingResult<[NewsItem]> {
        switch readBundledJSON(
            [APINewsItem].self,
            resourceName: "\(DataStore.year)_news"
        ) {
        case .loaded(let news), .stale(let news):
            return .loaded(news.map(convertAPINewsItemToNewsItem))
        case .notFound:
            return .notFound
        case .unparsable:
            return .unparsable
        }
    }

    func storeAPIRudolstadtDataToFile(data: APIRudolstadtData, fileName: String)
        -> Bool
    {
        let dataFile = cacheFileURL(for: fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: dataFile)
        } catch {
            AppLog.data.error(
                "Failed to cache festival data in \(dataFile.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
        return FileManager.default.fileExists(atPath: dataFile.path)
    }

    func deleteCachedFestivalData() -> Bool {
        deleteCachedFile(fileName: "rudolstadt_data.json", logger: AppLog.data)
    }

    func cachedFestivalDataModificationDate() -> Date? {
        modificationDate(for: "rudolstadt_data.json")
    }
    
    func storeAPINewsToFile(news: [APINewsItem], fileName: String) -> Bool {
        let dataFile = cacheFileURL(for: fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let jsonData = try encoder.encode(news)
            try jsonData.write(to: dataFile)
        } catch {
            AppLog.news.error(
                "Failed to cache news in \(dataFile.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
        return FileManager.default.fileExists(atPath: dataFile.path)
    }

    func readAPIRudolstadtDataFromFile(fileName: String) -> (
        APIRudolstadtData?, Bool
    ) {
        let stale = isFileStale(fileName: fileName)
        let dataFile = cacheFileURL(for: fileName)

        do {
            let data = try Data(contentsOf: dataFile)
            let decoder = JSONDecoder()
            let apiData = try decoder.decode(APIRudolstadtData.self, from: data)
            return (apiData, stale)
        } catch {
            if !isMissingFile(error) {
                AppLog.data.error(
                    "Failed to read cached festival data from \(dataFile.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
            return (nil, stale)
        }
    }

    func readAPINewsFromFile(fileName: String) -> ([APINewsItem]?, Bool) {
        let stale = isFileStale(fileName: fileName)
        let dataFile = cacheFileURL(for: fileName)

        do {
            let data = try Data(contentsOf: dataFile)
            let decoder = JSONDecoder()
            let apiData = try decoder.decode([APINewsItem].self, from: data)
            return (apiData, stale)
        } catch {
            if !isMissingFile(error) {
                AppLog.news.error(
                    "Failed to read cached news from \(dataFile.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
            return (nil, stale)
        }
    }

    func isFileStale(fileName: String) -> Bool {
        let someTimeAgo = Calendar.current.date(
            byAdding: .hour,
            value: -3,
            to: Date.now
        )
        return isFileOlderThan(fileName: fileName, date: someTimeAgo)
    }

    func cacheFileURL(for fileName: String) -> URL {
        cacheURL.appendingPathComponent("\(DataStore.year)_\(fileName)")
    }

    func isFileOlderThan(fileName: String, date: Date?) -> Bool {
        guard let modificationDate = modificationDate(for: fileName) else {
            return false
        }

        if let someTimeAgo = date {
            return modificationDate < someTimeAgo
        }
        return Calendar.current.compare(
            modificationDate,
            to: .now,
            toGranularity: .day
        ) == .orderedAscending
    }

    private func modificationDate(for fileName: String) -> Date? {
        let dataFile = cacheFileURL(for: fileName)

        do {
            let attr = try FileManager.default.attributesOfItem(
                atPath: dataFile.path
            )
            return attr[FileAttributeKey.modificationDate] as? Date
        } catch {
            return nil
        }
    }

    private func readCachedJSON<T: Decodable>(
        _ type: T.Type,
        fileName: String
    ) -> CacheReadResult<T> {
        let stale = isFileStale(fileName: fileName)
        let dataFile = cacheFileURL(for: fileName)

        do {
            let data = try Data(contentsOf: dataFile)
            let decodedValue = try JSONDecoder().decode(T.self, from: data)
            return .loaded(decodedValue, stale: stale)
        } catch {
            if isMissingFile(error) {
                return .notFound
            }
            return .unparsable
        }
    }

    private func readBundledJSON<T: Decodable>(
        _ type: T.Type,
        resourceName: String
    ) -> FileLoadingResult<T> {
        let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "json"
        ) ?? Bundle.main.url(
            forResource: resourceName,
            withExtension: "json",
            subdirectory: "FestivalBackup"
        )

        guard let url else {
            return .notFound
        }

        do {
            let data = try Data(contentsOf: url)
            return .loaded(try JSONDecoder().decode(type, from: data))
        } catch {
            return .unparsable
        }
    }

    private func deleteCachedFile(fileName: String, logger: Logger) -> Bool {
        let dataFile = cacheFileURL(for: fileName)

        do {
            guard FileManager.default.fileExists(atPath: dataFile.path) else {
                return true
            }
            try FileManager.default.removeItem(at: dataFile)
            return true
        } catch {
            logger.error(
                "Failed to delete cached file \(dataFile.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    private func isMissingFile(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain
            && nsError.code == NSFileReadNoSuchFileError
    }
}
