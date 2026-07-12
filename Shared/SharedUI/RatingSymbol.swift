import SwiftUI

struct RatingSymbol: View {
    let rating: Int
    @EnvironmentObject var settings: UserSettings
    @ScaledMetric(relativeTo: .body) private var circleRadius: CGFloat = 4
    @ScaledMetric(relativeTo: .body) private var stackWidth: CGFloat = 26
    @ScaledMetric(relativeTo: .body) private var stackHeight: CGFloat = 22

    var body: some View {
        if rating <= 0 {
            Text("No Rating")
                .foregroundColor(.secondary)

        } else {
            Group {
                if settings.likeIcon == "heart.fill" {
                    RatingHeartGlyph(rating: visibleRating, color: .red)
                        .shadow(
                            color: .black.opacity(0.18),
                            radius: 1,
                            y: 0.5
                        )
                } else {
                    ZStack {
                        ForEach(0..<visibleRating, id: \.self) { index in
                            RatingSymbolGlyph(systemName: settings.likeIcon)
                                .scaleEffect(glyphScale)
                                .offset(offset(for: index))
                                .zIndex(Double(index))
                        }
                    }
                }
            }
            .frame(width: stackWidth, height: stackHeight)
        }
    }

    private var visibleRating: Int {
        min(rating, 3)
    }

    private func offset(for index: Int) -> CGSize {
        guard visibleRating > 1 else {
            return .zero
        }

        let angle = angle(for: index) * .pi / 180

        return CGSize(
            width: cos(angle) * circleRadius,
            height: sin(angle) * circleRadius
        )
    }

    private func angle(for index: Int) -> CGFloat {
        switch visibleRating {
        case 1:
            return 0
        case 2:
            return [210, 30][index]
        default:
            return [135, 255, 15][index]
        }
    }

    private var glyphScale: CGFloat {
        switch visibleRating {
        case 1:
            return 1
        case 2:
            return 0.8
        default:
            return 0.7
        }
    }
}

struct RatingHeartGlyph: View {
    let rating: Int
    let color: Color

    private var assetName: String {
        "rating-heart-\(min(max(rating, 1), 3))"
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(color)
    }
}

private struct RatingSymbolGlyph: View {
    let systemName: String

    var body: some View {
        ZStack {
            Image(systemName: systemName)
                .foregroundStyle(.white)
                .scaleEffect(1.22)
                .shadow(color: .black.opacity(0.16), radius: 0.5)

            Image(systemName: systemName)
                .foregroundStyle(.red)
        }
    }
}

#if DEBUG
private struct RatingSymbolPreviewRow<Content: View>: View {
    let title: String
    let content: () -> Content

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .trailing)

            content()
                .foregroundStyle(.secondary)
                .ratingSymbolPreviewBounds()
        }
    }
}

private struct RatingSymbolPreviewBounds: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 25, height: 25)
            .overlay(
                Rectangle()
                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5)
            )
    }
}

private extension View {
    func ratingSymbolPreviewBounds() -> some View {
        modifier(RatingSymbolPreviewBounds())
    }
}

private struct RatingSymbolPreviewShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("RatingSymbol") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0...4, id: \.self) { rating in
                        RatingSymbolPreviewRow(title: "rating \(rating)") {
                            RatingSymbol(rating: rating)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox("ArtistRatingSymbol") {
                VStack(alignment: .leading, spacing: 10) {
                    RatingSymbolPreviewRow(title: "negative") {
                        ArtistRatingSymbol(
                            rating: -1,
                            iconName: "questionmark.circle.fill"
                        )
                    }

                    RatingSymbolPreviewRow(title: "positive") {
                        ArtistRatingSymbol(rating: 3, iconName: nil)
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox("Compact") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 18) {
                        CompactArtistRatingSymbol(
                            rating: -1,
                            iconName: "hand.thumbsdown.fill"
                        )
                        .ratingSymbolPreviewBounds()
                        CompactArtistRatingSymbol(rating: 1, iconName: nil)
                            .ratingSymbolPreviewBounds()
                        CompactArtistRatingSymbol(rating: 2, iconName: nil)
                            .ratingSymbolPreviewBounds()
                        CompactArtistRatingSymbol(rating: 3, iconName: nil)
                            .ratingSymbolPreviewBounds()
                    }

                    HStack(spacing: 18) {
                        CompactArtistRatingSymbol(
                            rating: -1,
                            iconName: "hand.thumbsdown.fill",
                            style: .imageOverlay
                        )
                        .ratingSymbolPreviewBounds()
                        CompactArtistRatingSymbol(
                            rating: 1,
                            iconName: nil,
                            style: .imageOverlay
                        )
                        .ratingSymbolPreviewBounds()
                        CompactArtistRatingSymbol(
                            rating: 2,
                            iconName: nil,
                            style: .imageOverlay
                        )
                        .ratingSymbolPreviewBounds()
                        CompactArtistRatingSymbol(
                            rating: 3,
                            iconName: nil,
                            style: .imageOverlay
                        )
                        .ratingSymbolPreviewBounds()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
        }
        .padding()
    }
}

struct RatingSymbol_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        RatingSymbolPreviewShowcase()
            .environmentObject(UserSettings())
            .previewLayout(.sizeThatFits)
    }
}
#endif
