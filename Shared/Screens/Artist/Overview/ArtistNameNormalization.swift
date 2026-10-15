import Foundation

func normalizedArtistName(_ name: String, locale: Locale = .current) -> String {
    name.folding(
        options: [
            .diacriticInsensitive, .caseInsensitive, .widthInsensitive,
        ],
        locale: locale
    )
}

func artistsForOverview(
    _ artists: [Artist],
    favoritesOnly: Bool,
    ratings: [String: Int],
    searchTerm: String = "",
    locale: Locale = .current
) -> [Artist] {
    let normalizedSearchTerm = normalize(string: searchTerm, locale: locale)
    let entries = artists.compactMap { artist -> (artist: Artist, name: String, rating: Int)? in
        let rating = ratings[String(artist.id)] ?? 0
        guard !favoritesOnly || rating > 0 else {
            return nil
        }
        let name = normalizedArtistName(artist.name, locale: locale)
        guard normalizedSearchTerm.isEmpty || name.contains(normalizedSearchTerm) else {
            return nil
        }
        return (artist, name, rating)
    }

    return entries.sorted { first, second in
        if first.name != second.name {
            return first.name < second.name
        }
        // Preserve the previous rating order for equally normalized favorite names.
        return favoritesOnly && first.rating > second.rating
    }.map(\.artist)
}
