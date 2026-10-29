import Foundation

func normalizedArtistName(_ name: String, locale: Locale = .current) -> String {
    name.folding(
        options: [
            .diacriticInsensitive, .caseInsensitive, .widthInsensitive,
        ],
        locale: locale
    )
}

struct ArtistOverviewIndex {
    private struct Entry {
        let search: CoreDiscoveryArtist
        let groups: [String: Set<String>]
    }
    private let entries: [Entry]
    private let byID: [Int: Artist]

    init(_ artists: [Artist], locale: Locale = .current) {
        entries = artists.filter { !$0.hiddenFromArtistList }.map {
            Entry(search: CoreDiscoveryArtist($0, locale: locale), groups: $0.groupIDs)
        }
        byID = Dictionary(artists.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func matching(
        favoritesOnly: Bool, ratings: [String: Int], searchTerm: String = "",
        selectedGroups: [String: String] = [:], locale: Locale = .current
    ) -> [Artist] {
        let candidates = entries.filter { entry in
            selectedGroups.allSatisfy { entry.groups[$0.key]?.contains($0.value) == true }
        }
        let request = CoreDiscoveryRequest(
            artists: candidates.map(\.search),
            ratings: Dictionary(
                ratings.compactMap { key, value in Int(key).map { ($0, value) } },
                uniquingKeysWith: { _, last in last }),
            favoritesOnly: favoritesOnly, search: normalize(string: searchTerm, locale: locale))
        return KotlinCore.artistOverview(request).compactMap { byID[$0] }
    }
}
