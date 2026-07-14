import SwiftUI

struct ArtistBrowseView: View {
    let artists: [Artist]
    @ObservedObject var state: ArtistOverviewState
    let currentTipID: String?
    let emptyMessageKey: LocalizedStringKey
    let browseGenreOptions: [BrowseTaxonomyEntry]
    let localizedBrowseGenreLabel: (String) -> String
    let navigationTitleKey: LocalizedStringKey
    let imageTransitionNamespace: Namespace.ID
    let navigate: (AppNavigationRoute) -> Void

    private var sortedArtists: [Artist] {
        artists.sorted { first, second in
            normalizedArtistName(first.name) < normalizedArtistName(second.name)
        }
    }

    var body: some View {
        Group {
            if state.selectedPresentationMode == .grid {
                ArtistOverviewGridView(
                    artists: sortedArtists,
                    gridDensity: state.selectedGridDensity,
                    emptyMessageKey: emptyMessageKey,
                    imageTransitionNamespace: imageTransitionNamespace,
                    showsWorldMapCallout: state.searchText.isEmpty,
                    showWorldMap: showWorldMap
                )
            } else {
                ArtistOverviewListView(
                    artists: sortedArtists,
                    emptyMessageKey: emptyMessageKey,
                    showsWorldMapCallout: state.searchText.isEmpty,
                    showWorldMap: showWorldMap
                )
            }
        }
        .searchable(text: $state.searchText)
        .disableAutocorrection(true)
        .navigationTitle(navigationTitleKey)
        .toolbar {
            ArtistListToolbar(
                state: state,
                currentTipID: currentTipID,
                browseGenreOptions: browseGenreOptions,
                localizedBrowseGenreLabel: localizedBrowseGenreLabel
            )
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(nil, for: .navigationBar)
    }

    private func showWorldMap() {
        navigate(.artistWorldMap)
    }
}

#if DEBUG
@MainActor
private struct ArtistBrowseViewPreview: View {
    @StateObject private var state = ArtistOverviewState()
    @Namespace private var namespace

    private var previewArtists: [Artist] {
        Array(
            PreviewMockData.festivalData.artists
                .filter { artist in
                    !artist.hiddenFromArtistList && artist.fullImageUrl != nil
                }
                .prefix(18)
        )
    }

    var body: some View {
        NavigationStack {
            ArtistBrowseView(
                artists: previewArtists,
                state: state,
                currentTipID: nil,
                emptyMessageKey: "artists.none-found",
                browseGenreOptions: [],
                localizedBrowseGenreLabel: { $0 },
                navigationTitleKey: "artists.title",
                imageTransitionNamespace: namespace,
                navigate: { _ in }
            )
            .navigationDestination(for: AppNavigationRoute.self) { _ in
                EmptyView()
            }
        }
    }
}

struct ArtistBrowseView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        ArtistBrowseViewPreview()
            .previewMockEnvironment(suiteName: "ArtistBrowseViewPreview")
    }
}
#endif
