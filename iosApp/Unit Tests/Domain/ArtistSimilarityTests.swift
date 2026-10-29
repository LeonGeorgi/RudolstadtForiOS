import RudolstadtCore
import Foundation
import Testing
@testable import Rudolstadt

struct ArtistSimilarityTests {
    @Test
    func preservesExportedRankingAndLimitsResults() {
        let artists = (1...5).map { TestFixtures.artist(id: $0) }
        let catalog = ArtistSimilarityCatalog(
            festivalYear: 2026, similarArtistIDsByArtistID: [1: [3, 5, 2]]
        )

        #expect(catalog.similarArtists(
            to: artists[0], among: artists, festivalYear: 2026
        ).map(\.id) == [3, 5, 2])
        #expect(catalog.similarArtists(
            to: artists[0], among: artists, festivalYear: 2026, limit: 2
        ).map(\.id) == [3, 5])
    }

    @Test
    func filtersUnavailableHiddenAndCurrentArtistBeforeApplyingLimit() {
        let artist = TestFixtures.artist(id: 1)
        let catalog = ArtistSimilarityCatalog(
            festivalYear: 2026, similarArtistIDsByArtistID: [1: [1, 2, 3, 5, 6]]
        )
        let liveArtists = [
            artist,
            TestFixtures.artist(id: 3, hiddenFromArtistList: true),
            TestFixtures.artist(id: 5), TestFixtures.artist(id: 6),
        ]

        #expect(catalog.similarArtists(
            to: artist, among: liveArtists, festivalYear: 2026, limit: 1
        ).map(\.id) == [5])
    }

    @Test
    func requiresMatchingYearKnownIDAndPositiveLimit() {
        let artists = (1...2).map { TestFixtures.artist(id: $0) }
        let catalog = ArtistSimilarityCatalog(
            festivalYear: 2026, similarArtistIDsByArtistID: [1: [2]]
        )

        #expect(catalog.similarArtists(
            to: artists[0], among: artists, festivalYear: 2027
        ).isEmpty)
        #expect(catalog.similarArtists(
            to: TestFixtures.artist(id: 99), among: artists, festivalYear: 2026
        ).isEmpty)
        #expect(catalog.similarArtists(
            to: artists[0], among: artists, festivalYear: 2026, limit: 0
        ).isEmpty)
    }

    @Test
    func nameCorrectionsDoNotRemoveMatches() {
        let artist = TestFixtures.artist(id: 1, name: "Corrected source name")
        let candidate = TestFixtures.artist(id: 2, name: "Corrected candidate name")
        let catalog = ArtistSimilarityCatalog(
            festivalYear: 2026, similarArtistIDsByArtistID: [1: [2]]
        )
        #expect(catalog.similarArtists(
            to: artist, among: [artist, candidate], festivalYear: 2026
        ).map(\.name) == [candidate.name])
    }

    @Test
    func bundledCatalogResolvesRealProgramAndCapsListsAtFive() throws {
        let url = try #require(Bundle.main.url(
            forResource: "\(FestivalConfiguration.year)_rudolstadt_data", withExtension: "json"
        ))
        let apiData = try TestFixtures.sourcePayload(Data(contentsOf: url))
        let program = try convertFestivalSourceToEntities(
            apiData: apiData, extraData: .empty()
        )
        let catalog = ArtistSimilarityCatalog.bundled
        #expect(catalog.festivalYear == FestivalConfiguration.year)
        let programIDs = Set(program.artists.map(\.id))
        #expect(!catalog.similarArtistIDsByArtistID.isEmpty)
        for (artistID, candidateIDs) in catalog.similarArtistIDsByArtistID {
            #expect(programIDs.contains(artistID))
            #expect(candidateIDs.allSatisfy { programIDs.contains($0) && $0 != artistID })
        }
        #expect(program.artists.contains { artist in
            !catalog.similarArtists(
                to: artist, among: program.artists, festivalYear: FestivalConfiguration.year
            ).isEmpty
        })
        for artist in program.artists {
            let matches = catalog.similarArtists(
                to: artist, among: program.artists, festivalYear: FestivalConfiguration.year
            )
            #expect(matches.count <= 5)
            #expect(matches.allSatisfy { $0.id != artist.id && !$0.hiddenFromArtistList })
        }
    }
}
