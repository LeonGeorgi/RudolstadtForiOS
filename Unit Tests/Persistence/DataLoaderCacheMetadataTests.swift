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
