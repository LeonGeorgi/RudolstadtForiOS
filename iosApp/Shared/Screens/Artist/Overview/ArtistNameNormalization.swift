import Foundation
import RudolstadtCore

func normalizedArtistName(_ name: String, locale: Locale = .current) -> String {
    name.folding(
        options: [
            .diacriticInsensitive, .caseInsensitive, .widthInsensitive,
        ],
        locale: locale
    )
}

struct ArtistOverviewIndex {
    private let index: ProgramArtistIndex

    init(_ artists: [Artist], locale: Locale = .current) {
        index = ProgramArtistIndex(artists: artists, fold: { normalizedArtistName($0, locale: locale) })
    }

    func matching(
        favoritesOnly: Bool, ratings: [String: Int], searchTerm: String = "",
        selectedGroups: [String: String] = [:], locale: Locale = .current
    ) -> [Artist] {
        KotlinCore.matchingArtists(
            index,
            favoritesOnly: favoritesOnly,
            ratings: ratings,
            search: normalize(string: searchTerm, locale: locale),
            groups: selectedGroups)
    }
}
