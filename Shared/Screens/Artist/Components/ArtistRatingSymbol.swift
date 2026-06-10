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

    private var visibleRating: Int {
        min(max(rating, 0), 3)
    }

    var body: some View {
        ZStack {
            ForEach(0..<visibleRating, id: \.self) { index in
                ZStack {
                    Image(systemName: iconName)
                        .font(.system(size: glyphSize * 1.22, weight: .bold))
                        .foregroundStyle(haloColor)

                    Image(systemName: iconName)
                        .font(.system(size: glyphSize, weight: .bold))
                        .foregroundStyle(color)
                }
                .offset(offset(for: index))
                .zIndex(Double(index))
            }
        }
        .frame(width: size + spread * 2, height: size + spread * 2)
    }

    private var glyphSize: CGFloat {
        switch visibleRating {
        case 1:
            return size
        case 2:
            return size * 0.82
        default:
            return size * 0.72
        }
    }

    private func offset(for index: Int) -> CGSize {
        guard visibleRating > 1 else {
            return .zero
        }

        let angle = angle(for: index) * .pi / 180
        return CGSize(
            width: cos(angle) * spread,
            height: sin(angle) * spread
        )
    }

    private func angle(for index: Int) -> CGFloat {
        switch visibleRating {
        case 2:
            return [210, 30][index]
        case 3:
            return [135, 255, 15][index]
        default:
            return 0
        }
    }
}

#if DEBUG
private struct ArtistRatingSymbolPreviewBounds: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 34, height: 34)
            .overlay(
                Rectangle()
                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5)
            )
            .overlay(
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5)
            )
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
