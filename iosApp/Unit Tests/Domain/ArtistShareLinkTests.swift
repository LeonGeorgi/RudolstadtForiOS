import Foundation
import Testing
@testable import Rudolstadt

struct ArtistShareLinkTests {
    @Test
    func sharesYearAndStableArtistID() throws {
        let link = ArtistShareLink(year: 2026, artistID: 123)
        let url = try #require(link.url)

        #expect(url.absoluteString == "https://rudolstadt.leongeorgi.de/2026/artists/123")
        #expect(ArtistShareLink(url: url) == link)
    }

    @Test(arguments: [
        "https://rudolstadt.leongeorgi.de/2026/artists/123/",
        "https://rudolstadt.leongeorgi.de/2026/artists/123?utm_source=share#artist",
        "https://RUDOLSTADT.LEONGEORGI.DE:443/2026/artists/123",
    ])
    func acceptsWebLinkVariants(_ value: String) throws {
        let url = try #require(URL(string: value))
        #expect(ArtistShareLink(url: url) == ArtistShareLink(year: 2026, artistID: 123))
    }

    @Test
    func preservesOtherFestivalYearsForAvailabilityCheck() throws {
        let url = try #require(URL(string: "https://rudolstadt.leongeorgi.de/2025/artists/123"))
        let link = try #require(ArtistShareLink(url: url))
        #expect(link.year == 2025)
        #expect(link.artistID == 123)
    }

    @Test(arguments: [
        "http://rudolstadt.leongeorgi.de/2026/artists/123",
        "https://example.com/2026/artists/123",
        "https://rudolstadt.leongeorgi.de.example.com/2026/artists/123",
        "https://rudolstadt.leongeorgi.de@evil.example/2026/artists/123",
        "https://user@rudolstadt.leongeorgi.de/2026/artists/123",
        "https://rudolstadt.leongeorgi.de:8443/2026/artists/123",
        "https://rudolstadt.leongeorgi.de/",
        "https://rudolstadt.leongeorgi.de/artists/123",
        "https://rudolstadt.leongeorgi.de/2026/stages/123",
        "https://rudolstadt.leongeorgi.de/2026/artists/123/extra",
        "https://rudolstadt.leongeorgi.de/year/artists/123",
        "https://rudolstadt.leongeorgi.de/26/artists/123",
        "https://rudolstadt.leongeorgi.de/0000/artists/123",
        "https://rudolstadt.leongeorgi.de/2026/artists/name",
        "https://rudolstadt.leongeorgi.de/2026/artists/0",
        "https://rudolstadt.leongeorgi.de/2026/artists/-123",
        "https://rudolstadt.leongeorgi.de/2026/artists/+123",
        "https://rudolstadt.leongeorgi.de/2026/artists/999999999999999999999999",
    ])
    func ignoresUnrelatedOrMalformedLinks(_ value: String) throws {
        let url = try #require(URL(string: value))
        #expect(ArtistShareLink(url: url) == nil)
    }

    @Test
    func doesNotGenerateLinksForInvalidIdentifiers() {
        #expect(ArtistShareLink(year: 26, artistID: 123).url == nil)
        #expect(ArtistShareLink(year: 2026, artistID: 0).url == nil)
        #expect(ArtistShareLink(year: 2026, artistID: -1).url == nil)
    }
}
