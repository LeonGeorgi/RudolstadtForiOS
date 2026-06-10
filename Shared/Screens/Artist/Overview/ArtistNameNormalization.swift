import Foundation

func normalizedArtistName(_ name: String) -> String {
    name.folding(
        options: [
            .diacriticInsensitive, .caseInsensitive, .widthInsensitive,
        ],
        locale: Locale.current
    )
}
