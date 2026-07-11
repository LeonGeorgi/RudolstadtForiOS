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
