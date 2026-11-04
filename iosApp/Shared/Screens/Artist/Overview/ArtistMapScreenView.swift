import SwiftUI

struct ArtistMapScreenView: View {
    let artists: [Artist]
    let navigationTitleKey: LocalizedStringKey
    var navigate: ((AppNavigationRoute) -> Void)? = nil

    var body: some View {
        ArtistMapOverviewView(
            artists: artists,
            navigate: navigate
        )
        .navigationTitle(navigationTitleKey)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
