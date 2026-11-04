import Foundation
import Testing
@testable import Rudolstadt

struct ArtistShareLinkTests {
    @Test
    func sharesSelectedConcertAndPreservesQueryThroughTheNativeAdapter() throws {
        let link = ArtistShareLink(year: 2026, artistID: 67, eventID: 68)
        let url = try #require(link.url)
        #expect(url.absoluteString == "https://festival.leongeorgi.de/rudolstadt/2026/artists/67?event=68")
        #expect(ArtistShareLink(url: url) == link)
        let variant = try #require(URL(string: "https://festival.leongeorgi.de/rudolstadt/2026/artists/67/?source=share&event=%36%38#concert"))
        #expect(ArtistShareLink(url: variant) == link)
        let links = RudolstadtPublicLinks(year: 2026)
        #expect(links.destination(for: variant) == .artist(67, highlightedEventID: 68))
        #expect(links.url(for: .artist(67, highlightedEventID: 68)) == url)
        #expect(RudolstadtPublicLinks(year: 2025).destination(for: url) == nil)
    }

    @Test(arguments: ["event=", "event=oops", "event=0", "event=-1", "event=68&event=244", "event=999999999999999999999999"])
    func invalidConcertQueryKeepsArtistAvailable(_ query: String) throws {
        let url = try #require(URL(string: "https://festival.leongeorgi.de/rudolstadt/2026/artists/67?\(query)"))
        #expect(ArtistShareLink(url: url) == ArtistShareLink(year: 2026, artistID: 67))
    }

    @MainActor @Test
    func resolvesSelectionAgainstTheArtistsConcerts() {
        let artist = TestFixtures.artist(id: 67)
        let other = TestFixtures.artist(id: 23)
        let stage = TestFixtures.stage(id: 14)
        let events = [
            TestFixtures.event(id: 68, dayInJuly: 3, timeAsString: "17:00", stage: stage, artist: artist),
            TestFixtures.event(id: 69, dayInJuly: 3, timeAsString: "18:00", stage: stage, artist: other),
        ]
        #expect(ArtistShareLink(year: 2026, artistID: 67, eventID: 68).selectedEventID(in: events) == 68)
        #expect(ArtistShareLink(year: 2026, artistID: 67, eventID: 69).selectedEventID(in: events) == nil)
        #expect(ArtistShareLink(year: 2026, artistID: 67, eventID: 999).selectedEventID(in: events) == nil)
    }

    @Test
    func existingEncodedArtistDestinationsRemainReadable() throws {
        let legacy = Data(#"{"artist":{"_0":67}}"#.utf8)
        #expect(try JSONDecoder().decode(FestivalDestination.self, from: legacy) == .artist(67))
        let selected = FestivalDestination.artist(67, highlightedEventID: 68)
        let encoded = try JSONEncoder().encode(selected)
        #expect(try JSONDecoder().decode(FestivalDestination.self, from: encoded) == selected)
    }

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
        #expect(ArtistShareLink(year: 2026, artistID: 67, eventID: 0).url == nil)
    }
}
