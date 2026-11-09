import SwiftUI

struct ArtistRatingSymbol: View {
    let rating: Int
    let iconName: String?

    var body: some View {
        if rating < 0 {
            Image(systemName: iconName ?? "hand.thumbsdown.fill")
        } else if rating == 0 {
            // return empty view
            EmptyView()
        } else {
            RatingSymbol(rating: rating)
        }
    }
}

struct CompactArtistRatingSymbol: View {
    enum Style {
        case inline
        case imageOverlay
    }

    let rating: Int
    let iconName: String?
    var style: Style = .inline
    var negativeColor: Color = .secondary
    var negativeShadowColor: Color? = nil
    var negativeShadowRadius: CGFloat? = nil
    var negativeShadowY: CGFloat? = nil

    @EnvironmentObject private var settings: UserSettings

    var body: some View {
        if rating < 0 {
            symbolContent(iconName: iconName ?? "hand.thumbsdown.fill")
                .accessibilityLabel(Text("Negative rating"))
                .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
        } else if rating > 0 {
            ratingContent(iconName: iconName ?? settings.likeIcon)
                .accessibilityLabel(Text("\(rating) artist rating"))
        } else {
            EmptyView()
        }
    }

    private func ratingContent(iconName: String) -> some View {
        CompactRatingGlyph(
            rating: rating,
            iconName: iconName,
            color: ratingColor,
            size: glyphSize,
            spread: glyphSpread
        )
        .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }

    private func symbolContent(iconName: String) -> some View {
        Image(systemName: iconName)
            .font(.system(size: glyphSize, weight: .bold))
            .foregroundStyle(ratingColor)
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }

    private var ratingColor: Color {
        rating > 0 ? .red : negativeColor
    }

    private var glyphSize: CGFloat {
        switch style {
        case .inline:
            return 13
        case .imageOverlay:
            return 17
        }
    }

    private var glyphSpread: CGFloat {
        switch style {
        case .inline:
            return 4
        case .imageOverlay:
            return 5
        }
    }

    private var shadowColor: Color {
        if rating < 0, let negativeShadowColor {
            return negativeShadowColor
        }

        return style == .imageOverlay
            ? Color.black.opacity(0.32)
            : Color.black.opacity(0.12)
    }

    private var shadowRadius: CGFloat {
        if rating < 0, let negativeShadowRadius {
            return negativeShadowRadius
        }

        return style == .imageOverlay ? 5 : 2
    }

    private var shadowY: CGFloat {
        if rating < 0, let negativeShadowY {
            return negativeShadowY
        }

        return style == .imageOverlay ? 2 : 1
    }
}

struct CompactRatingGlyph: View {
    let rating: Int
    let iconName: String
    var color: Color
    var size: CGFloat
    var spread: CGFloat
    var haloColor: Color = .white

    var body: some View {
        RatingGlyphs(
            rating: rating, iconName: iconName, spread: spread,
            heart: { count in RatingHeartGlyph(rating: count, color: color) },
            symbol: { count in symbol(for: count) }
        )
        .frame(width: size + spread * 2, height: size + spread * 2)
    }

    private func symbol(for count: Int) -> some View {
        let glyphSize: CGFloat
        switch count {
        case 1: glyphSize = size
        case 2: glyphSize = size * 0.82
        default: glyphSize = size * 0.72
        }
        return ZStack {
            Image(systemName: iconName)
                .font(.system(size: glyphSize * 1.22, weight: .bold))
                .foregroundStyle(haloColor)

            Image(systemName: iconName)
                .font(.system(size: glyphSize, weight: .bold))
                .foregroundStyle(color)
        }
    }
}

struct AnimatedRatingHeartGlyph: View {
    private struct Placement {
        let scale: CGFloat
        var x: CGFloat = 0
        var y: CGFloat = 0
        var isVisible = true
    }

    // Centers and scales in the assets' 24-point viewport, ordered core, right, left.
    private static let placements: [[Placement]] = [
        [
            Placement(scale: 0.82, isVisible: false),
            Placement(scale: 0.38, isVisible: false),
            Placement(scale: 0.38, isVisible: false),
        ],
        [
            Placement(scale: 1),
            Placement(scale: 0.38, isVisible: false),
            Placement(scale: 0.38, isVisible: false),
        ],
        [
            Placement(scale: 0.78 / 1.35, x: -5.525, y: 2.5),
            Placement(scale: 0.78 / 1.35, x: 5.525, y: -2.5),
            Placement(scale: 0.38, x: -5.525, y: 2.5, isVisible: false),
        ],
        [
            Placement(scale: 0.67 / 1.35, y: 6.56667),
            Placement(scale: 0.67 / 1.35, x: 5.9, y: -3.28333),
            Placement(scale: 0.67 / 1.35, x: -5.9, y: -3.28333),
        ],
    ]

    let rating: Int
    let color: Color
    let size: CGFloat
    let spread: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let rating = min(max(self.rating, 0), 3)
        let placements = Self.placements[rating]
        let artworkSize = size + spread * 2
        let unit = artworkSize / 24
        let isEmpty = rating == 0

        ZStack {
            Image(systemName: "heart")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(color)
                .opacity(isEmpty ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.135), value: isEmpty)

            ForEach(placements.indices, id: \.self) { index in
                let placement = placements[index]
                let revealDelay = placement.isVisible ? Double(index) * 0.016 : 0

                RatingHeartGlyph(rating: 1, color: color)
                    .frame(width: artworkSize, height: artworkSize)
                    .opacity(placement.isVisible ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.135).delay(revealDelay),
                        value: placement.isVisible
                    )
                    .scaleEffect(placement.scale)
                    .offset(x: placement.x * unit, y: placement.y * unit)
            }
        }
        .animation(
            reduceMotion ? nil : .timingCurve(0.21, 0.76, 0.27, 1, duration: 0.285),
            value: rating
        )
    }
}

#if DEBUG
private struct ArtistRatingSymbolPreviewBounds: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 34, height: 34)
            .overlay {
                Rectangle()
                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5)
            }
            .overlay {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5)
            }
    }
}

private extension View {
    func artistRatingSymbolPreviewBounds() -> some View {
        modifier(ArtistRatingSymbolPreviewBounds())
    }
}

private struct ArtistRatingSymbolPreviewRow<Content: View>: View {
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
                .artistRatingSymbolPreviewBounds()
        }
    }
}

private struct ArtistRatingSymbolPreviewShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("ArtistRatingSymbol") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(-1...4, id: \.self) { rating in
                        ArtistRatingSymbolPreviewRow(title: "rating \(rating)") {
                            ArtistRatingSymbol(
                                rating: rating,
                                iconName: rating < 0
                                    ? "questionmark.circle.fill"
                                    : nil
                            )
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox("CompactArtistRatingSymbol") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 18) {
                        ForEach(-1...4, id: \.self) { rating in
                            CompactArtistRatingSymbol(
                                rating: rating,
                                iconName: rating < 0
                                    ? "hand.thumbsdown.fill"
                                    : nil
                            )
                            .artistRatingSymbolPreviewBounds()
                        }
                    }

                    HStack(spacing: 18) {
                        ForEach(-1...4, id: \.self) { rating in
                            CompactArtistRatingSymbol(
                                rating: rating,
                                iconName: rating < 0
                                    ? "questionmark.circle.fill"
                                    : nil,
                                style: .imageOverlay
                            )
                            .artistRatingSymbolPreviewBounds()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }
}

struct ArtistRatingSymbol_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        ArtistRatingSymbolPreviewShowcase()
            .environmentObject(UserSettings())
            .previewLayout(.sizeThatFits)
    }
}
#endif
