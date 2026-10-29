import Foundation
import CryptoKit
import RudolstadtCore
import OSLog

protocol FestivalDataCaching: Sendable {
    /// Fast launch path: never converts raw API data or performs network I/O.
    func loadConvertedFestivalDataFromFile(
        extraData: ExtraDataCollection
    ) -> FileLoadingResult<FestivalData>
    func storeConvertedFestivalDataToFile(
        program: FestivalProgram, source: RudolstadtPayload, extraData: ExtraDataCollection)
    func loadFestivalDataFromFile(
        extraData: ExtraDataCollection
    ) -> FileLoadingResult<FestivalData>
    func loadBundledFestivalDataBackup(
        extraData: ExtraDataCollection
    ) -> FileLoadingResult<FestivalData>
    func storeFestivalSourceToFile(
        data: RudolstadtPayload,
        fileName: String
    ) -> Bool
    func deleteCachedFestivalData() -> Bool
    func cachedFestivalDataModificationDate() -> Date?
    func isFileStale(fileName: String) -> Bool
}

extension FestivalDataCaching {
    func loadConvertedFestivalDataFromFile(
        extraData: ExtraDataCollection
    ) -> FileLoadingResult<FestivalData> { .notFound }
    func storeConvertedFestivalDataToFile(
        program: FestivalProgram, source: RudolstadtPayload, extraData: ExtraDataCollection
    ) {}
}

private struct ConvertedFestivalCache: Codable {
    let build: String
    let sourceHash: String
    let extraHash: String
    let programHash: String
    let programJSON: Data
}

protocol BundledNewsLoading: Sendable {
    func loadBundledNewsBackup() -> FileLoadingResult<[NewsItem]>
}

final class DataLoader: @unchecked Sendable {
    private static let convertedCacheName = "program-v2.plist"
    // Conversion changes, including local development builds, invalidate derived data.
    private static let convertedCacheBuild: String = {
        let bundle = Bundle.main
        let binaries = [
            bundle.executableURL, bundle.executableURL?.appendingPathExtension("debug.dylib"),
        ]
        let dates = binaries.map { url in
            (try? url?.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate)?.timeIntervalSince1970 ?? 0
        }
        return "2/\(bundle.infoDictionary?["CFBundleVersion"] ?? "")/\(dates)"
    }()
    let cacheURL: URL
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    init(
        cacheURL: URL,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.cacheURL = cacheURL
        self.calendar = calendar
        self.now = now
    }

    func loadFestivalDataFromFile(
        extraData: ExtraDataCollection
    ) -> FileLoadingResult<FestivalData> {
        loadCachedProgram(extraData: extraData, convertedOnly: false)
    }

    func loadConvertedFestivalDataFromFile(
        extraData: ExtraDataCollection
    ) -> FileLoadingResult<FestivalData> {
        loadCachedProgram(extraData: extraData, convertedOnly: true)
    }

    private func loadCachedProgram(extraData: ExtraDataCollection, convertedOnly: Bool)
        -> FileLoadingResult<FestivalData>
    {
        do {
            let source = try Data(contentsOf: cacheFileURL(for: "rudolstadt_data.json"))
            let program: FestivalProgram
            if let converted = convertedProgram(source: source, extraData: extraData) {
                program = converted
            } else {
                guard !convertedOnly else { return .notFound }
                let apiData = try KotlinCore.bridge.decodeRudolstadtPayload(
                    sourceJSON: sourceJSONString(source))
                program = try convertFestivalSourceToProgram(apiData: apiData, extraData: extraData)
                do { try storeConvertedProgram(program, source: source, extraData: extraData) } catch {
                    AppLog.data.error(
                        "Cannot cache converted program: \(error.localizedDescription)")
                }
            }
            let data = try program.native()
            return isFileStale(fileName: "rudolstadt_data.json") ? .stale(data) : .loaded(data)
        } catch {
            if isMissingFile(error) { return .notFound }
            if !convertedOnly {
                AppLog.data.error("Invalid cached program: \(error.localizedDescription)")
            }
            return .unparsable
        }
    }

    private func convertedProgram(source: Data, extraData: ExtraDataCollection)
        -> FestivalProgram?
    {
        guard let bytes = try? Data(contentsOf: cacheFileURL(for: Self.convertedCacheName)),
            let cache = try? PropertyListDecoder().decode(ConvertedFestivalCache.self, from: bytes),
            cache.build == Self.convertedCacheBuild,
            cache.sourceHash == Self.hash(source),
            cache.extraHash == Self.hash(Data(extraData.sourceJSON.utf8)),
            cache.programHash == Self.hash(cache.programJSON)
        else { return nil }
        return try? KotlinCore.bridge.decodeProgram(cacheJSON: String(decoding: cache.programJSON, as: UTF8.self))
    }

    func storeConvertedFestivalDataToFile(
        program: FestivalProgram, source: RudolstadtPayload, extraData: ExtraDataCollection
    ) {
        do {
            try storeConvertedProgram(
                program, source: Data(source.sourceJSON.utf8), extraData: extraData)
        } catch {
            AppLog.data.error("Cannot cache converted program: \(error.localizedDescription)")
        }
    }

    private func storeConvertedProgram(_ value: FestivalProgram, source: Data, extraData: ExtraDataCollection)
        throws
    {
        let program = Data(try KotlinCore.bridge.encodeProgram(program: value).utf8)
        let cache = ConvertedFestivalCache(
            build: Self.convertedCacheBuild,
            sourceHash: Self.hash(source),
            extraHash: Self.hash(Data(extraData.sourceJSON.utf8)),
            programHash: Self.hash(program), programJSON: program)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(cache).write(
            to: cacheFileURL(for: Self.convertedCacheName), options: .atomic)
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func loadBundledFestivalDataBackup(
        extraData: ExtraDataCollection
    ) -> FileLoadingResult<FestivalData> {
        guard let url = bundledJSONURL(resourceName: "\(DataStore.year)_rudolstadt_data") else {
            return .notFound
        }
        do {
            let payload = try KotlinCore.bridge.decodeRudolstadtPayload(
                sourceJSON: String(contentsOf: url, encoding: .utf8))
            return .loaded(try convertFestivalSourceToEntities(apiData: payload, extraData: extraData))
        } catch {
            AppLog.data.error("Invalid bundled program: \(error.localizedDescription)")
            return .unparsable
        }
    }

    func loadNewsFromFile() -> FileLoadingResult<[NewsItem]> {
        readNews(at: cacheFileURL(for: "news.json"), stale: isFileStale(fileName: "news.json"))
    }
    func loadBundledNewsBackup() -> FileLoadingResult<[NewsItem]> {
        guard let url = bundledJSONURL(resourceName: "\(DataStore.year)_news") else {
            return .notFound
        }
        return readNews(at: url, stale: false)
    }
    private func readNews(at url: URL, stale: Bool) -> FileLoadingResult<[NewsItem]> {
        do {
            let items = try NewsWire.shared.decodeMessages(
                sourceJSON: sourceJSONString(Data(contentsOf: url)))
            return stale ? .stale(items) : .loaded(items)
        } catch { return isMissingFile(error) ? .notFound : .unparsable }
    }

    func storeFestivalSourceToFile(data: RudolstadtPayload, fileName: String)
        -> Bool
    {
        let dataFile = cacheFileURL(for: fileName)
        do {
            let jsonData = Data(data.sourceJSON.utf8)
            try jsonData.write(to: dataFile, options: .atomic)
            return true
        } catch {
            AppLog.data.error(
                "Failed to cache festival data in \(dataFile.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
        return false
    }

    func deleteCachedFestivalData() -> Bool {
        deleteCachedFile(fileName: "rudolstadt_data.json", logger: AppLog.data)
            && deleteCachedFile(fileName: Self.convertedCacheName, logger: AppLog.data)
            && deleteCachedFile(fileName: "program-v1.plist", logger: AppLog.data)
    }

    func cachedFestivalDataModificationDate() -> Date? {
        modificationDate(for: "rudolstadt_data.json")
    }

    func storeAPINewsToFile(news: [APINewsItem], fileName: String) -> Bool {
        do {
            try Data(NewsWire.shared.encode(records: news).utf8).write(
                to: cacheFileURL(for: fileName), options: .atomic)
            return true
        } catch {
            AppLog.news.error(
                "Failed to cache news: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func isFileStale(fileName: String) -> Bool {
        CachePolicy.shared.isStale(modifiedAt: modificationDate(for: fileName).map { KotlinDouble(value: $0.timeIntervalSince1970) }, now: now().timeIntervalSince1970)
    }

    func cacheFileURL(for fileName: String) -> URL {
        cacheURL.appendingPathComponent(CachePolicy.shared.fileName(year: Int32(DataStore.year), name: fileName))
    }

    func isFileOlderThan(fileName: String, date: Date?) -> Bool {
        guard let modificationDate = modificationDate(for: fileName) else {
            return true
        }

        if let someTimeAgo = date {
            return CachePolicy.shared.isOlderThan(modifiedAt: KotlinDouble(value: modificationDate.timeIntervalSince1970), cutoff: someTimeAgo.timeIntervalSince1970)
        }
        return calendar.compare(
            modificationDate,
            to: now(),
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

    private func bundledJSONURL(resourceName: String) -> URL? {
        Bundle.main.url(forResource: resourceName, withExtension: "json")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "json", subdirectory: "FestivalBackup")
    }

    func deleteCachedNews() -> Bool { deleteCachedFile(fileName: "news.json", logger: AppLog.news) }

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

extension DataLoader: FestivalDataCaching, BundledNewsLoading {}
