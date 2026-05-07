import SwiftUI

struct ArtistMapScreenView: View {
    let artists: [Artist]
    @ObservedObject var state: ArtistOverviewState
    let navigate: (AppNavigationRoute) -> Void

    var body: some View {
        ArtistMapOverviewView(
            artists: artists,
            navigate: navigate
        )
        .navigationBarTitle("artists.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ArtistPresentationModeToolbar(state: state)
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
