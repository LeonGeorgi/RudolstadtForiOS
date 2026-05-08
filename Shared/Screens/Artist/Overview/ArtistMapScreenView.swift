import SwiftUI

struct ArtistMapScreenView: View {
    let artists: [Artist]
    let navigationTitleKey: LocalizedStringKey
    let navigate: (AppNavigationRoute) -> Void

    @State private var selectedCountryCode: String? = nil

    init(
        artists: [Artist],
        navigationTitleKey: LocalizedStringKey,
        navigate: @escaping (AppNavigationRoute) -> Void = { _ in }
    ) {
        self.artists = artists
        self.navigationTitleKey = navigationTitleKey
        self.navigate = navigate
    }

    var body: some View {
        ArtistMapOverviewView(
            artists: artists,
            selectedCountryCode: $selectedCountryCode,
            navigate: navigate
        )
        .navigationTitle(navigationTitleKey)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
