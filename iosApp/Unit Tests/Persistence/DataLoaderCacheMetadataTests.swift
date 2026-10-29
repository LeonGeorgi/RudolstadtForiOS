import RudolstadtCore
import Foundation
import Testing

@testable import Rudolstadt

struct DataLoaderCacheMetadataTests {
    @Test
    func cachedFestivalDataModificationDateReadsCacheFileDate() throws {
        let cacheURL = try makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheURL) }

        let loader = DataLoader(cacheURL: cacheURL)
        let cacheFileURL = loader.cacheFileURL(for: "rudolstadt_data.json")
        let expectedDate = Date(timeIntervalSince1970: 1_700_000_000)

        try Data("{}".utf8).write(to: cacheFileURL)
        try FileManager.default.setAttributes(
            [.modificationDate: expectedDate],
            ofItemAtPath: cacheFileURL.path
        )

        let actualDate = try #require(
            loader.cachedFestivalDataModificationDate()
        )
        #expect(
            abs(
                actualDate.timeIntervalSince1970
                    - expectedDate.timeIntervalSince1970
            ) <= 1
        )
    }

    @Test
    func cachedFestivalDataModificationDateReturnsNilWhenMissing() throws {
        let cacheURL = try makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheURL) }

        let loader = DataLoader(cacheURL: cacheURL)

        #expect(loader.cachedFestivalDataModificationDate() == nil)
    }

    @Test
    func cacheOlderThanThreeHoursIsStaleForInjectedTime() throws {
        let cacheURL = try makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheURL) }
        let now = TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        let loader = DataLoader(
            cacheURL: cacheURL,
            calendar: TestFixtures.festivalCalendar,
            now: { now }
        )
        try createCacheFile(
            using: loader,
            fileName: "news.json",
            modificationDate: now.addingTimeInterval(-4 * 60 * 60)
        )

        #expect(loader.isFileStale(fileName: "news.json"))
    }

    @Test
    func cacheNewerThanThreeHoursIsFreshForInjectedTime() throws {
        let cacheURL = try makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheURL) }
        let now = TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        let loader = DataLoader(
            cacheURL: cacheURL,
            calendar: TestFixtures.festivalCalendar,
            now: { now }
        )
        try createCacheFile(
            using: loader,
            fileName: "news.json",
            modificationDate: now.addingTimeInterval(-2 * 60 * 60)
        )

        #expect(!loader.isFileStale(fileName: "news.json"))
    }

    @Test
    func festivalDataWriteReportsSuccessAndReplacesCache() throws {
        let directory = try makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let loader = DataLoader(cacheURL: directory)

        #expect(loader.storeFestivalSourceToFile(
            data: TestFixtures.apiFestivalData(artistID: 1),
            fileName: "rudolstadt_data.json"
        ))
        #expect(loader.storeFestivalSourceToFile(
            data: TestFixtures.apiFestivalData(artistID: 2),
            fileName: "rudolstadt_data.json"
        ))

        let cachedData = try Data(contentsOf: loader.cacheFileURL(for: "rudolstadt_data.json"))
        let cached = try TestFixtures.sourcePayload(cachedData)
        #expect(try TestFixtures.sourceRecords(cached, "artists").compactMap { $0["id"] as? Int } == [2])
    }

    @Test
    func failedFestivalDataWriteReportsFailureAndPreservesExistingCache() throws {
        let directory = try makeTemporaryCacheDirectory()
        let loader = DataLoader(cacheURL: directory)
        let fileURL = loader.cacheFileURL(for: "rudolstadt_data.json")
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            try? FileManager.default.removeItem(at: directory)
        }
        #expect(loader.storeFestivalSourceToFile(
            data: TestFixtures.apiFestivalData(artistID: 1),
            fileName: "rudolstadt_data.json"
        ))
        let previousCache = try Data(contentsOf: fileURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o400], ofItemAtPath: fileURL.path)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500], ofItemAtPath: directory.path)

        #expect(!loader.storeFestivalSourceToFile(
            data: TestFixtures.apiFestivalData(artistID: 2),
            fileName: "rudolstadt_data.json"
        ))
        #expect(try Data(contentsOf: fileURL) == previousCache)
    }

    @Test(arguments: [false, true])
    func legacyRawCacheIsConvertedOnceWithoutRewritingItsDownloadDate(hasOldConvertedCache: Bool) throws {
        let directory = try makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let loader = DataLoader(cacheURL: directory)
        #expect(
            loader.storeFestivalSourceToFile(
                data: TestFixtures.apiFestivalData(artistID: 1), fileName: "rudolstadt_data.json"))
        let date = try #require(loader.cachedFestivalDataModificationDate())
        if hasOldConvertedCache {
            let old: [String: Any] = ["build": "1/old", "sourceHash": "old", "extraHash": "old",
                "programHash": "old", "programJSON": Data("{}".utf8)]
            try PropertyListSerialization.data(fromPropertyList: old, format: .binary, options: 0)
                .write(to: loader.cacheFileURL(for: "program-v1.plist"))
        }
        guard case .notFound = loader.loadConvertedFestivalDataFromFile(extraData: .empty()) else {
            Issue.record("The launch path must not convert a legacy cache synchronously")
            return
        }
        guard case .loaded(let migrated) = loader.loadFestivalDataFromFile(extraData: .empty()),
            case .loaded(let restored) = DataLoader(cacheURL: directory)
                .loadConvertedFestivalDataFromFile(extraData: .empty())
        else {
            Issue.record("Expected the migrated fast cache")
            return
        }
        #expect(migrated.artists.map(\.id) == [1])
        #expect(restored.artists.map(\.id) == [1])
        #expect(loader.cachedFestivalDataModificationDate() == date)
    }

    @Test(arguments: ["build", "programJSON"])
    func incompatibleOrCorruptConvertedCacheFallsBackToRawData(field: String) throws {
        let directory = try makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let loader = DataLoader(cacheURL: directory)
        try writeConvertedCache(using: loader)
        let file = loader.cacheFileURL(for: "program-v2.plist")
        var snapshot = try #require(
            PropertyListSerialization.propertyList(
                from: Data(contentsOf: file), format: nil) as? [String: Any])
        if field == "build" {
            snapshot[field] = "older-app-build"
        } else {
            snapshot[field] = Data("{}".utf8)
        }
        try PropertyListSerialization.data(fromPropertyList: snapshot, format: .binary, options: 0)
            .write(to: file)

        guard case .notFound = loader.loadConvertedFestivalDataFromFile(extraData: .empty()),
            case .loaded(let recovered) = loader.loadFestivalDataFromFile(extraData: .empty()),
            case .loaded = loader.loadConvertedFestivalDataFromFile(extraData: .empty())
        else {
            Issue.record("A derived cache must be replaceable from the original cache")
            return
        }
        #expect(recovered.artists.map(\.id) == [1])
    }

    @Test
    func changedRawDataOrExtrasInvalidatesConvertedCache() throws {
        let directory = try makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let loader = DataLoader(cacheURL: directory)
        try writeConvertedCache(using: loader)
        #expect(
            loader.storeFestivalSourceToFile(
                data: TestFixtures.apiFestivalData(artistID: 2), fileName: "rudolstadt_data.json"))
        guard case .notFound = loader.loadConvertedFestivalDataFromFile(extraData: .empty()),
            case .loaded(let refreshed) = loader.loadFestivalDataFromFile(extraData: .empty())
        else {
            Issue.record("Expected the changed raw cache")
            return
        }
        #expect(refreshed.artists.map(\.id) == [2])
        let changedExtras = try KotlinCore.bridge.decodeProgramExtras(sourceJSON: #"{"data":{"Changed":{"browse_genres":[]}}}"#)
        guard case .notFound = loader.loadConvertedFestivalDataFromFile(extraData: changedExtras),
            case .loaded = loader.loadFestivalDataFromFile(extraData: changedExtras),
            case .loaded = loader.loadConvertedFestivalDataFromFile(extraData: changedExtras)
        else {
            Issue.record("Changed enrichment must rebuild the derived cache")
            return
        }
    }

    @Test
    func convertedCacheUsesRawCacheAgeAndCannotOutliveDeletion() throws {
        let directory = try makeTemporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date.now
        let loader = DataLoader(cacheURL: directory, now: { now })
        try writeConvertedCache(using: loader)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-4 * 60 * 60)],
            ofItemAtPath: loader.cacheFileURL(for: "rudolstadt_data.json").path)
        guard case .stale(let data) = loader.loadConvertedFestivalDataFromFile(extraData: .empty())
        else {
            Issue.record("Converted data must not make an old download look fresh")
            return
        }
        #expect(data.artists.map(\.id) == [1])
        #expect(loader.deleteCachedFestivalData())
        #expect(
            !FileManager.default.fileExists(
                atPath: loader.cacheFileURL(for: "program-v2.plist").path))
        guard case .notFound = loader.loadConvertedFestivalDataFromFile(extraData: .empty()) else {
            Issue.record("Deleted program data must stay deleted")
            return
        }
    }

    private func writeConvertedCache(using loader: DataLoader) throws {
        let source = TestFixtures.apiFestivalData(artistID: 1)
        #expect(loader.storeFestivalSourceToFile(data: source, fileName: "rudolstadt_data.json"))
        loader.storeConvertedFestivalDataToFile(
            program: try convertFestivalSourceToProgram(
                apiData: source, extraData: .empty()),
            source: source, extraData: .empty())
    }

    private func createCacheFile(
        using loader: DataLoader,
        fileName: String,
        modificationDate: Date
    ) throws {
        let fileURL = loader.cacheFileURL(for: fileName)
        try Data("{}".utf8).write(to: fileURL)
        try FileManager.default.setAttributes(
            [.modificationDate: modificationDate],
            ofItemAtPath: fileURL.path
        )
    }

    private func makeTemporaryCacheDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }
}

struct NewsDiskCacheTests {
    @Test
    func atomicWriteReplacesValidCacheAndUnreadableCacheIsExplicit() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let loader = DataLoader(cacheURL: directory)
        #expect(
            loader.storeAPINewsToFile(
                news: [TestFixtures.apiNewsItem(id: 1, language: "en")], fileName: "news.json"))
        #expect(
            loader.storeAPINewsToFile(
                news: [TestFixtures.apiNewsItem(id: 2, language: "de")], fileName: "news.json"))
        switch loader.loadNewsFromFile() {
        case .loaded(let items), .stale(let items): #expect(items.map(\.id) == [2])
        default: Issue.record("Expected the replacement cache")
        }
        try Data("invalid JSON".utf8).write(to: loader.cacheFileURL(for: "news.json"))
        guard case .unparsable = loader.loadNewsFromFile() else {
            Issue.record("Corrupt cache must not look like an empty success")
            return
        }
    }

    @Test
    func failedAtomicWriteReportsFailureAndPreservesPreviousCache() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }
        let loader = DataLoader(cacheURL: directory)
        #expect(
            loader.storeAPINewsToFile(
                news: [TestFixtures.apiNewsItem(id: 1, language: "en")], fileName: "news.json"))
        let original = try Data(contentsOf: loader.cacheFileURL(for: "news.json"))
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500], ofItemAtPath: directory.path)
        #expect(
            !loader.storeAPINewsToFile(
                news: [TestFixtures.apiNewsItem(id: 2, language: "en")], fileName: "news.json"))
        #expect(try Data(contentsOf: loader.cacheFileURL(for: "news.json")) == original)
    }

    @Test
    func absentMetadataDoesNotSuppressRefresh() {
        let loader = DataLoader(
            cacheURL: FileManager.default.temporaryDirectory.appendingPathComponent(
                UUID().uuidString))
        #expect(loader.isFileOlderThan(fileName: "news.json", date: Date()))
    }
}
