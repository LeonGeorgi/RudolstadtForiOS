import SwiftUI

struct ArtistSimilarArtistsBlock: View {
    let artists: [Artist]

    @Environment(\.locale) private var locale
    @EnvironmentObject private var profile: FestivalProfileStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("artist.similar-artists")
                .font(.title2.bold())
                .accessibilityHeading(.h2)

            ForEach(artists) { artist in
                NavigationLink(
                    value: AppNavigationRoute.artist(
                        id: artist.id,
                        highlightedEventId: nil,
                        transitionSourceID: nil
                    )
                ) {
                    FestivalListRow {
                        ArtistListRowImage(artist: artist, loadingStyle: .quiet)
                    } content: {
                        FestivalListRowTitle(artist.formattedName)
                        if let countries = localizedArtistCountryDescription(
                            rawValue: artist.countries,
                            countryCodes: artist.countryCodes,
                            locale: locale
                        ) {
                            Text(countries)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } accessories: {
                        ArtistRatingListSlot(
                            rating: profile.rating(for: artist.id),
                            iconName: profile.iconName(forArtistID: artist.id),
                            reservesSpace: false
                        )

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("similar-artist-\(artist.id)")
            }
        }
    }
}
