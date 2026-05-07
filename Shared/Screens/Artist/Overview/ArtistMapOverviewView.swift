import SwiftUI

struct ArtistMapOverviewView: View {
    let artists: [Artist]
    let navigate: (AppNavigationRoute) -> Void

    @State private var selectedCountryCode: String? = nil

    private var sortedArtists: [Artist] {
        artists.sorted { first, second in
            normalizedArtistName(first.name) < normalizedArtistName(second.name)
        }
    }

    private var countryGroups: [ArtistCountryGroup] {
        let groupedArtists = Dictionary(
            grouping: sortedArtists.flatMap { artist in
                artist.countryCodes.map { countryCode in
                    (countryCode, artist)
                }
            },
            by: \.0
        )

        return groupedArtists.map { countryCode, entries in
            ArtistCountryGroup(
                code: countryCode,
                artists: entries.map(\.1)
            )
        }.sorted { first, second in
            if first.count == second.count {
                return first.localizedName.localizedCaseInsensitiveCompare(
                    second.localizedName
                ) == .orderedAscending
            }
            return first.count > second.count
        }
    }

    var body: some View {
        ArtistWorldMapView(
            groups: countryGroups,
            selectedCountryCode: $selectedCountryCode,
            navigate: navigate
        )
        .onAppear {
            syncSelectedCountryCode()
        }
        .onChange(of: countryGroups.map(\.code)) {
            syncSelectedCountryCode()
        }
        .onChange(of: selectedCountryCode) {
            guard let selectedCountryCode else {
                return
            }
            navigate(.artistCountry(code: selectedCountryCode))
            self.selectedCountryCode = nil
        }
    }

    private func syncSelectedCountryCode() {
        if let selectedCountryCode,
            countryGroups.contains(where: { $0.code == selectedCountryCode })
        {
            return
        }

        self.selectedCountryCode = nil
    }
}
