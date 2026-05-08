import SwiftUI

struct ArtistMapScreenView: View {
    let artists: [Artist]
    let navigationTitleKey: LocalizedStringKey

    @State private var selectedCountryCode: String? = nil

    private var isShowingCountryDetail: Binding<Bool> {
        Binding(
            get: {
                selectedCountryCode != nil
            },
            set: { isPresented in
                if !isPresented {
                    selectedCountryCode = nil
                }
            }
        )
    }

    var body: some View {
        ArtistMapOverviewView(
            artists: artists,
            selectedCountryCode: $selectedCountryCode
        )
        .navigationBarTitle(navigationTitleKey)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .tabBar)
        .navigationDestination(isPresented: isShowingCountryDetail) {
            if let selectedCountryCode {
                ArtistCountryListRouteView(countryCode: selectedCountryCode)
            }
        }
    }
}
