import Foundation
import Testing

@testable import Rudolstadt

struct ArtistOverviewOrderingTests {
    private let locale = Locale(identifier: "en_US")

    @Test
    func sortsNamesIgnoringCaseDiacriticsAndWidth() {
        let artists = [
            TestFixtures.artist(id: 1, name: "Zulu"),
            TestFixtures.artist(id: 2, name: "Ｂeta"),
            TestFixtures.artist(id: 3, name: "álpha"),
        ]

        let index = ArtistOverviewIndex(artists, locale: locale)
        let result = index.matching(
            favoritesOnly: false, ratings: [:], locale: locale
        )

        #expect(result.map(\.id) == [3, 2, 1])
    }

    @Test
    func searchesNormalizedNamesAndKeepsTheFinalAlphabeticalOrder() {
        let artists = [
            TestFixtures.artist(id: 1, name: "Zulu Beta"),
            TestFixtures.artist(id: 2, name: "Béta"),
            TestFixtures.artist(id: 3, name: "Other"),
        ]

        let index = ArtistOverviewIndex(artists, locale: locale)
        let result = index.matching(
            favoritesOnly: true,
            ratings: ["1": 3, "2": 1, "3": 1],
            searchTerm: "  ＢETA  ",
            locale: locale
        )

        #expect(result.map(\.id) == [2, 1])
    }

    @Test
    func favoritesExcludeUnratedAndNonPositiveRatingsAndRemainAlphabetical() {
        let artists = [
            TestFixtures.artist(id: 1, name: "Zulu"),
            TestFixtures.artist(id: 2, name: "Alpha"),
            TestFixtures.artist(id: 3, name: "Beta"),
            TestFixtures.artist(id: 4, name: "Delta"),
            TestFixtures.artist(id: 5, name: "Echo"),
        ]

        let index = ArtistOverviewIndex(artists, locale: locale)
        let result = index.matching(
            favoritesOnly: true,
            ratings: ["1": 3, "2": 1, "3": 0, "4": -1],
            locale: locale
        )

        #expect(result.map(\.id) == [2, 1])
    }

    @Test
    func equallyNormalizedNamesUseRatingsOnlyInFavoritesModeAndPreserveTies() {
        let artists = [
            TestFixtures.artist(id: 1, name: "Alpha"),
            TestFixtures.artist(id: 2, name: "Álpha"),
            TestFixtures.artist(id: 3, name: "ALPHA"),
        ]
        let ratings = ["1": 1, "2": 3, "3": 3]

        let index = ArtistOverviewIndex(artists, locale: locale)
        let favorites = index.matching(
            favoritesOnly: true, ratings: ratings, locale: locale
        )
        let allArtists = index.matching(
            favoritesOnly: false, ratings: ratings, locale: locale
        )

        #expect(favorites.map(\.id) == [2, 3, 1])
        #expect(allArtists.map(\.id) == [1, 2, 3])
    }
    @Test
    func preparedIndexAppliesCurrentGroupsAndRatingsWithoutKeepingPreviousFilters() {
        let first = TestFixtures.artist(id: 1, name: "Alpha").replacing(groupIDs: ["kind": ["one"]])
        let second = TestFixtures.artist(id: 2, name: "Beta").replacing(groupIDs: ["kind": ["two"]])
        let index = ArtistOverviewIndex([first, second], locale: locale)
        #expect(
            index.matching(
                favoritesOnly: false, ratings: [:], searchTerm: "", selectedGroups: ["kind": "two"],
                locale: locale
            ).map(\.id) == [2])
        #expect(
            index.matching(favoritesOnly: true, ratings: ["1": 2], searchTerm: "", locale: locale)
                .map(\.id) == [1])
        #expect(
            index.matching(favoritesOnly: true, ratings: ["2": 3], searchTerm: "", locale: locale)
                .map(\.id) == [2])
        #expect(
            index.matching(favoritesOnly: false, ratings: [:], searchTerm: "ALPHA", locale: locale)
                .first === first)
    }

}
