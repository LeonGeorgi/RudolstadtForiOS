import SwiftUI

enum FestivalListRowStyle {
    static let imageWidth: CGFloat = 56
    static let imageHeight: CGFloat = 49
    static let imageCornerRadius: CGFloat = 8
    static let columnSpacing: CGFloat = 12
    static let twoLineSpacing: CGFloat = 4
    static let threeLineSpacing: CGFloat = 2
    static let tagFont: Font = .caption2.weight(.semibold)
    static let timeFont: Font = .subheadline.weight(.medium)
}

/// Shared layout for list rows; grids and timeline blocks have their own layout.
struct FestivalListRow<Leading: View, Content: View, Accessories: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let hasThirdLine: Bool
    private let alignment: VerticalAlignment
    private let leading: Leading
    private let content: Content
    private let accessories: Accessories?

    init(
        hasThirdLine: Bool = false,
        alignment: VerticalAlignment = .center,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder content: () -> Content,
        @ViewBuilder accessories: () -> Accessories
    ) {
        self.hasThirdLine = hasThirdLine
        self.alignment = alignment
        self.leading = leading()
        self.content = content()
        self.accessories = accessories()
    }

    var body: some View {
        HStack(
            alignment: dynamicTypeSize.isAccessibilitySize ? .top : alignment,
            spacing: FestivalListRowStyle.columnSpacing
        ) {
            leading

            VStack(
                alignment: .leading,
                spacing: hasThirdLine
                    ? FestivalListRowStyle.threeLineSpacing
                    : FestivalListRowStyle.twoLineSpacing
            ) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let accessories {
                HStack(spacing: 8) {
                    accessories
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}

extension FestivalListRow where Accessories == EmptyView {
    init(
        hasThirdLine: Bool = false,
        alignment: VerticalAlignment = .center,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder content: () -> Content
    ) {
        self.hasThirdLine = hasThirdLine
        self.alignment = alignment
        self.leading = leading()
        self.content = content()
        self.accessories = nil
    }
}

struct ArtistListRowImage: View {
    let artist: Artist
    var loadingStyle: ArtistImageLoadingStyle = .standard

    var body: some View {
        ArtistImageView(artist: artist, fullImage: false, loadingStyle: loadingStyle)
            .frame(
                width: FestivalListRowStyle.imageWidth,
                height: FestivalListRowStyle.imageHeight
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: FestivalListRowStyle.imageCornerRadius,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)
    }
}

struct FestivalListRowTitle: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let title: String
    private let lineLimit: Int

    init(_ title: String, lineLimit: Int = 2) {
        self.title = title
        self.lineLimit = lineLimit
    }

    var body: some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : lineLimit)
            .allowsTightening(true)
    }
}
