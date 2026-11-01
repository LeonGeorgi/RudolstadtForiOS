import Foundation
import Testing
@testable import Rudolstadt

struct ArtistShareLinkTests {
    @Test
    func sharesYearAndStableArtistID() throws {
        let link = ArtistShareLink(year: 2026, artistID: 123)
        let url = try #require(link.url)

        #expect(url.absoluteString == "https://festival.leongeorgi.de/rudolstadt/2026/artists/123")
        #expect(ArtistShareLink(url: url) == link)
    }

    @Test(arguments: [
        "https://festival.leongeorgi.de/rudolstadt/2026/artists/123/",
        "https://festival.leongeorgi.de/rudolstadt/2026/artists/123?utm_source=share#artist",
        "https://FESTIVAL.LEONGEORGI.DE:443/rudolstadt/2026/artists/123",
        "https://rudolstadt.leongeorgi.de/2026/artists/123",
        "https://RUDOLSTADT.LEONGEORGI.DE:443/2026/artists/123/?source=share#artist",
    ])
    func acceptsWebLinkVariants(_ value: String) throws {
        let url = try #require(URL(string: value))
        #expect(ArtistShareLink(url: url) == ArtistShareLink(year: 2026, artistID: 123))
    }

    @Test
    func preservesOtherFestivalYearsForAvailabilityCheck() throws {
        let url = try #require(URL(string: "https://festival.leongeorgi.de/rudolstadt/2025/artists/123"))
        let link = try #require(ArtistShareLink(url: url))
        #expect(link.year == 2025)
        #expect(link.artistID == 123)
    }

    @Test(arguments: [
        "http://festival.leongeorgi.de/rudolstadt/2026/artists/123",
        "https://example.com/rudolstadt/2026/artists/123",
        "https://festival.leongeorgi.de.example.com/rudolstadt/2026/artists/123",
        "https://festival.leongeorgi.de@evil.example/rudolstadt/2026/artists/123",
        "https://user@festival.leongeorgi.de/rudolstadt/2026/artists/123",
        "https://festival.leongeorgi.de:8443/rudolstadt/2026/artists/123",
        "https://festival.leongeorgi.de/",
        "https://festival.leongeorgi.de/artists/123",
        "https://festival.leongeorgi.de/2026/artists/123",
        "https://festival.leongeorgi.de/other/2026/artists/123",
        "https://festival.leongeorgi.de/Rudolstadt/2026/artists/123",
        "https://festival.leongeorgi.de/rudolstadt/2026/Artists/123",
        "https://rudolstadt.leongeorgi.de/rudolstadt/2026/artists/123",
        "https://festival.leongeorgi.de/rudolstadt/2026/stages/123",
        "https://festival.leongeorgi.de/rudolstadt/2026/artists/123/extra",
        "https://festival.leongeorgi.de/rudolstadt/year/artists/123",
        "https://festival.leongeorgi.de/rudolstadt/26/artists/123",
        "https://festival.leongeorgi.de/rudolstadt/0000/artists/123",
        "https://festival.leongeorgi.de/rudolstadt/2026/artists/name",
        "https://festival.leongeorgi.de/rudolstadt/2026/artists/0",
        "https://festival.leongeorgi.de/rudolstadt/2026/artists/-123",
        "https://festival.leongeorgi.de/rudolstadt/2026/artists/+123",
        "https://festival.leongeorgi.de/rudolstadt/2026/artists/999999999999999999999999",
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
