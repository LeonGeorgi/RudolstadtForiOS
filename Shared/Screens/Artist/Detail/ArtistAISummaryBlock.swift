import SwiftUI

struct ArtistAISummaryBlock: View {
    let artist: Artist

    @EnvironmentObject var settings: UserSettings

    private var headlineGradient: LinearGradient {
        let warm = OKHSLColorConverter.okhslToSRGB(.init(h: 0.02, s: 0.82, l: 0.71))
        let pink = OKHSLColorConverter.okhslToSRGB(.init(h: 0.89, s: 0.79, l: 0.68))
        let blue = OKHSLColorConverter.okhslToSRGB(.init(h: 0.67, s: 0.83, l: 0.69))
        let cyan = OKHSLColorConverter.okhslToSRGB(.init(h: 0.56, s: 0.79, l: 0.72))
        return LinearGradient(
            colors: [
                Color(red: warm.r, green: warm.g, blue: warm.b),
                Color(red: pink.r, green: pink.g, blue: pink.b),
                Color(red: blue.r, green: blue.g, blue: blue.b),
                Color(red: cyan.r, green: cyan.g, blue: cyan.b),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        if settings.aiSummaryEnabled, let ai = artist.ai, ai.hasContent {
            let localizedSummary = ai.localizedSummary?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            ArtistDetailContentBlock {
                Text("artist.ai.header")
                    .font(.headline)
                    .foregroundStyle(headlineGradient)

                if let localizedSummary, !localizedSummary.isEmpty {
                    Text(localizedSummary)
                        .font(.body)
                }

                Text("artist.ai.footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
    }
}

#if DEBUG
struct ArtistAISummaryBlock_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        ArtistAISummaryBlock(artist: PreviewMockData.featuredArtist)
            .padding()
            .previewMockEnvironment(suiteName: "ArtistAISummaryBlockPreview")
            .previewLayout(.sizeThatFits)
    }
}
#endif
