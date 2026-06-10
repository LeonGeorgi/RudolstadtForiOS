import SwiftUI

struct ArtistOverviewGridView: View {
    let artists: [Artist]
    let emptyMessageKey: LocalizedStringKey
    let imageTransitionNamespace: Namespace.ID
    let showsWorldMapCallout: Bool
    let showWorldMap: () -> Void

    @EnvironmentObject private var profile: FestivalProfileStore

    private let gridColumns = Array(
        repeating: GridItem(.flexible(), spacing: 11),
        count: 3
    )

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if showsWorldMapCallout {
                    ArtistWorldMapCalloutCard(action: showWorldMap)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }

                if artists.isEmpty {
                    ArtistOverviewEmptyMessage(emptyMessageKey)
                        .frame(minHeight: 240)
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(artists) { artist in
                            NavigationLink(
                                value: AppNavigationRoute.artist(
                                    id: artist.id,
                                    highlightedEventId: nil,
                                    transitionSourceID: artist.id
                                )
                            ) {
                                ArtistGridCell(
                                    artist: artist,
                                    imageTransitionNamespace: imageTransitionNamespace,
                                    artistRating: profile.rating(for: artist.id),
                                    artistIconName: profile.iconName(forArtistID: artist.id),
                                    friendRatingSummary: profile.friendArtistRatingSummary(for: artist.id)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, showsWorldMapCallout ? 4 : 14)
                    .padding(.bottom, 14)
                }
            }
        }
    }
}

#if DEBUG
@MainActor
private struct ArtistOverviewGridViewPreview: View {
    @Namespace private var namespace

    private var previewArtists: [Artist] {
        let artists = PreviewMockData.festivalData.artists
            .filter { artist in
                !artist.hiddenFromArtistList && artist.fullImageUrl != nil
            }
        let preferredTypes: [ArtistType] = [.stage, .dance, .street, .other]
        let preferredArtists = preferredTypes.compactMap { artistType in
            artists.first { $0.artistType == artistType }
        }
        let fillerArtists = artists.filter { artist in
            !preferredArtists.contains { $0.id == artist.id }
        }

        return Array((preferredArtists + fillerArtists).prefix(12))
    }

    var body: some View {
        NavigationStack {
            ArtistOverviewGridView(
                artists: previewArtists,
                emptyMessageKey: "artists.none-found",
                imageTransitionNamespace: namespace,
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

struct ArtistOverviewGridView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        ArtistOverviewGridViewPreview()
            .previewMockEnvironment(suiteName: "ArtistOverviewGridViewPreview")
    }
}
#endif
