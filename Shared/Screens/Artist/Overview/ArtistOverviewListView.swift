import SwiftUI

struct ArtistOverviewListView: View {
    let artists: [Artist]
    let emptyMessageKey: LocalizedStringKey
    let showsWorldMapCallout: Bool
    let showWorldMap: () -> Void

    @EnvironmentObject private var profile: FestivalProfileStore

    var body: some View {
        List {
            if showsWorldMapCallout {
                ArtistWorldMapCalloutCard(action: showWorldMap)
                    .listRowInsets(
                        .init(top: 0, leading: 16, bottom: 4, trailing: 16)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if artists.isEmpty {
                ArtistOverviewEmptyMessage(emptyMessageKey)
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .listRowInsets(
                        .init(top: 20, leading: 24, bottom: 20, trailing: 24)
                    )
                    .listRowSeparator(.hidden)
            } else {
                ForEach(artists) { artist in
                    NavigationLink(
                        value: AppNavigationRoute.artist(
                            id: artist.id,
                            highlightedEventId: nil,
                            transitionSourceID: nil
                        )
                    ) {
                        ArtistCell(
                            artist: artist,
                            artistRating: profile.rating(for: artist.id),
                            artistIconName: profile.iconName(forArtistID: artist.id),
                            friendRatingSummary: profile.friendArtistRatingSummary(for: artist.id)
                        )
                    }
                    .accessibilityIdentifier("artist-\(artist.id)")
                    .listRowInsets(
                        .init(top: 0, leading: 0, bottom: 0, trailing: 16)
                    )
                }
            }
        }
        .listStyle(.plain)
    }
}

#if DEBUG
@MainActor
private struct ArtistOverviewListViewPreview: View {
    private var previewArtists: [Artist] {
        Array(
            PreviewMockData.festivalData.artists
                .filter { artist in
                    !artist.hiddenFromArtistList && artist.fullImageUrl != nil
                }
                .prefix(14)
        )
    }

    var body: some View {
        NavigationStack {
            ArtistOverviewListView(
                artists: previewArtists,
                emptyMessageKey: "artists.none-found",
                showsWorldMapCallout: true,
                showWorldMap: {}
            )
            .navigationTitle("artists.title")
            .navigationDestination(for: AppNavigationRoute.self) { _ in
                EmptyView()
            }
        }
    }
}

struct ArtistOverviewListView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        ArtistOverviewListViewPreview()
            .previewMockEnvironment(suiteName: "ArtistOverviewListViewPreview")
    }
}
#endif
