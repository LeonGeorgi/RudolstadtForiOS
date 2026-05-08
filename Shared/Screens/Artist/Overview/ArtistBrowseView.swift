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

    var body: some View {
        ArtistOverviewContentView(
            artists: artists,
            selectedPresentationMode: state.selectedPresentationMode,
            emptyMessageKey: emptyMessageKey,
            imageTransitionNamespace: imageTransitionNamespace,
            navigate: navigate
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
                    navigate(.artistWorldMap)
                }
            )
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(nil, for: .navigationBar)
        .toolbarColorScheme(nil, for: .tabBar)
    }
}
