import SwiftUI

struct ArtistDetailIntroView: View {
    let artist: Artist
    let topPadding: CGFloat

    @Environment(\.locale) private var locale
    @EnvironmentObject private var settings: UserSettings

    private var countryDescription: String? {
        localizedArtistCountryDescription(
            rawValue: artist.countries,
            countryCodes: artist.countryCodes,
            locale: locale
        )
    }

    private var localizedSummary: String? {
        guard settings.aiSummaryEnabled else {
            return nil
        }

        guard
            let summary = artist.ai?
                .localizedSummary(locale: locale)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !summary.isEmpty
        else {
            return nil
        }

        return summary
    }

    var body: some View {
        if countryDescription != nil || localizedSummary != nil {
            VStack(alignment: .leading, spacing: 6) {
                if let countryDescription {
                    Text(countryDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let localizedSummary {
                    Text(localizedSummary)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, topPadding)
        }
    }
}

#if DEBUG
struct ArtistDetailIntroView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        ArtistDetailIntroView(
            artist: PreviewMockData.featuredArtist,
            topPadding: 20
        )
            .padding()
            .previewMockEnvironment(suiteName: "ArtistDetailIntroViewPreview")
            .previewLayout(.sizeThatFits)
    }
}
#endif
