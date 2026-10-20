import SwiftUI

struct ArtistMapOverviewView: View {
    let artists: [Artist]

    var body: some View {
        let artistCountsByCountryCode = artists.reduce(into: [String: Int]()) { counts, artist in
            for code in artist.countryCodes {
                counts[code, default: 0] += 1
            }
        }

        ArtistWorldMapView(
            artistCountsByCountryCode: artistCountsByCountryCode
        )
    }
}
