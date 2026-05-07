import SwiftUI

struct ArtistBrowseView: View {
    let artists: [Artist]
    @ObservedObject var state: ArtistOverviewState
    let browseGenreOptions: [BrowseTaxonomyEntry]
    let localizedBrowseGenreLabel: (String) -> String
    let navigationTitleKey: LocalizedStringKey
    let imageTransitionNamespace: Namespace.ID

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
                browseGenreOptions: browseGenreOptions,
                localizedBrowseGenreLabel: localizedBrowseGenreLabel
            )
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(nil, for: .navigationBar)
        .toolbarColorScheme(nil, for: .tabBar)
    }
}
