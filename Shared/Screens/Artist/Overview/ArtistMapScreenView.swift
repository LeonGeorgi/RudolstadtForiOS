import SwiftUI

struct ArtistMapScreenView: View {
    let artists: [Artist]
    let navigationTitleKey: LocalizedStringKey

    var body: some View {
        ArtistMapOverviewView(
            artists: artists
        )
        .navigationBarTitle(navigationTitleKey)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .navigationBar, .tabBar)
    }
}
