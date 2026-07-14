import SwiftUI

enum ArtistGridLayout {
    static let horizontalPadding: CGFloat = 16
    static let columnSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 18

    static func columns(
        for dynamicTypeSize: DynamicTypeSize,
        density: ArtistGridDensity
    ) -> [GridItem] {
        let columnCount = dynamicTypeSize.isAccessibilitySize
            ? ArtistGridDensity.comfortable.rawValue
            : density.rawValue

        return Array(
            repeating: GridItem(
                .flexible(),
                spacing: columnSpacing,
                alignment: .top
            ),
            count: columnCount
        )
    }
}

struct ArtistOverviewGridView: View {
    let artists: [Artist]
    let gridDensity: ArtistGridDensity
    let emptyMessageKey: LocalizedStringKey
    let imageTransitionNamespace: Namespace.ID
    let showsWorldMapCallout: Bool
    let showWorldMap: () -> Void

    @EnvironmentObject private var profile: FestivalProfileStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var gridColumns: [GridItem] {
        ArtistGridLayout.columns(
            for: dynamicTypeSize,
            density: gridDensity
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if showsWorldMapCallout {
                    ArtistWorldMapCalloutCard(action: showWorldMap)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                }

                if artists.isEmpty {
                    ArtistOverviewEmptyMessage(emptyMessageKey)
                        .frame(minHeight: 240)
                } else {
                    LazyVGrid(
                        columns: gridColumns,
                        spacing: ArtistGridLayout.rowSpacing
                    ) {
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
                            .accessibilityIdentifier("artist-\(artist.id)")
                        }
                    }
                    .padding(.horizontal, ArtistGridLayout.horizontalPadding)
                    .padding(.top, showsWorldMapCallout ? 0 : 14)
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
                gridDensity: .comfortable,
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
