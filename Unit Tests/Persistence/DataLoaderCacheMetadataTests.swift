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
