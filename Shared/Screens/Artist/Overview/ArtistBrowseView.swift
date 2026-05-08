import SwiftUI

struct ArtistBrowseView: View {
    let artists: [Artist]
    let worldMapArtists: [Artist]
    @ObservedObject var state: ArtistOverviewState
    let currentTipID: String?
    let browseGenreOptions: [BrowseTaxonomyEntry]
    let localizedBrowseGenreLabel: (String) -> String
    let navigationTitleKey: LocalizedStringKey
    let imageTransitionNamespace: Namespace.ID
    let navigate: (AppNavigationRoute) -> Void

    @State private var isShowingWorldMap = false

    var body: some View {
        ArtistOverviewContentView(
            artists: artists,
            selectedPresentationMode: state.selectedPresentationMode,
            imageTransitionNamespace: imageTransitionNamespace
        )
        .searchable(text: $state.searchText)
        .disableAutocorrection(true)
        .navigationBarTitle(navigationTitleKey)
        .toolbar {
            ArtistListToolbar(
                state: state,
                currentTipID: currentTipID,
                browseGenreOptions: browseGenreOptions,
                localizedBrowseGenreLabel: localizedBrowseGenreLabel,
                showWorldMap: {
                    isShowingWorldMap = true
                }
            )
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(nil, for: .navigationBar)
        .toolbarColorScheme(nil, for: .tabBar)
        .navigationDestination(isPresented: $isShowingWorldMap) {
            ArtistMapScreenView(
                artists: worldMapArtists,
                navigationTitleKey: "artists.title"
            )
        }
    }
}
