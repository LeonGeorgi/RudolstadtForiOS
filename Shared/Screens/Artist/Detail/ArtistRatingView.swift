import SwiftUI

enum ArtistRatingCoordinateSpace {
    static let name = "artist-rating-viewport"
}

private struct ArtistRatingViewportHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var artistRatingViewportHeight: CGFloat {
        get { self[ArtistRatingViewportHeightKey.self] }
        set { self[ArtistRatingViewportHeightKey.self] = newValue }
    }
}

private enum ArtistRatingOptions {
    static let defaultAlternativeIcon = "hand.thumbsdown.fill"

    static let alternativeIcons = [
        "hand.thumbsdown.fill",
        "questionmark.circle.fill",
        "exclamationmark.triangle.fill",
        "clock.arrow.trianglehead.counterclockwise.rotate.90",
        "zzz",
        "moon.zzz.fill",
    ]

    static func baseSymbolName(for iconName: String) -> String {
        guard iconName.hasSuffix(".fill") else {
            return iconName
        }
        return String(iconName.dropLast(".fill".count))
    }

    static func localizedPositiveLabel(
        for rating: Int,
        iconName: String
    ) -> String {
        let iconKey = iconName == "flame.fill" ? ".flame" : ""
        return NSLocalizedString(
            "artist.rating.set\(iconKey).\(rating)",
            comment: "Artist rating option"
        )
    }

    static func localizedAlternativeLabel(for icon: String) -> String {
        let key = "artist.icon.\(icon)"
        let localizedLabel = NSLocalizedString(key, comment: "Icon for artist")
        guard localizedLabel != key else {
            return NSLocalizedString(
                "artist.icon.other",
                comment: "Generic alternative artist rating"
            )
        }
        return localizedLabel
    }

    static func localizedCurrentValue(
        for rating: Int,
        iconName: String
    ) -> String {
        if rating < 0 {
            return NSLocalizedString(
                "artist.rating.current.other",
                comment: "Current alternative artist rating"
            )
        }

        let iconKey = rating > 0 && iconName == "flame.fill" ? ".flame" : ""
        return NSLocalizedString(
            "artist.rating.current\(iconKey).\(rating)",
            comment: "Current artist rating"
        )
    }
}

struct ArtistRatingPopoverButton: View {
    private enum Layout {
        static let buttonSize: CGFloat = 50
        static let iconSize: CGFloat = 24
        static let friendRatingsVerticalOffset: CGFloat = -30
        static let minimumCompactPopoverSpace: CGFloat = 300
        static let minimumRegularPopoverSpace: CGFloat = 390
    }

    private enum PresentationLayout: Equatable {
        case sheet
        case compactPopover
        case regularPopover
    }

    let artist: Artist
    let currentTipID: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.artistRatingViewportHeight) private var viewportHeight
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var profile: FestivalProfileStore
    @State private var isShowingRatingPopover = false
    @State private var isShowingRatingSheet = false
    @State private var presentationLayout = PresentationLayout.sheet

    private var rating: Int {
        profile.rating(for: artist.id)
    }

    private var artistIcon: String? {
        guard rating < 0 else {
            return nil
        }

        return profile.iconName(forArtistID: artist.id)
            ?? ArtistRatingOptions.defaultAlternativeIcon
    }

    private var friendRatingSummary: FriendArtistRatingSummary? {
        profile.friendArtistRatingSummary(for: artist.id)
    }

    var body: some View {
        Button {
            if usesSheetPresentation {
                isShowingRatingSheet = true
            } else {
                isShowingRatingPopover = true
            }
        } label: {
            triggerIcon
                .frame(
                    width: Layout.buttonSize,
                    height: Layout.buttonSize
                )
                .contentShape(Circle())
                .background(triggerBackgroundColor, in: Circle())
                .foregroundStyle(.white)
                .accessibilityElement(children: .ignore)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .accessibilityLabel(Text("artist.rating.menu"))
        .accessibilityValue(Text(triggerAccessibilityValue))
        .overlay(alignment: .topTrailing) {
            if let friendRatingSummary {
                FriendArtistRatingsBubble(
                    summary: friendRatingSummary,
                    style: .detailInline
                )
                .fixedSize()
                .offset(y: Layout.friendRatingsVerticalOffset)
            }
        }
        .appPopoverTip(
            DiscoverabilityTips.artistRating,
            currentTipID: currentTipID,
            arrowEdge: .bottom
        )
        .onGeometryChange(for: PresentationLayout.self) { proxy in
            presentationLayout(
                triggerMaxY: proxy.frame(
                    in: .named(ArtistRatingCoordinateSpace.name)
                ).maxY
            )
        } action: { newLayout in
            presentationLayout = newLayout
        }
        .popover(
            isPresented: $isShowingRatingPopover,
            arrowEdge: .top
        ) {
            ArtistRatingPalette(
                artist: artist,
                forcesCompactLayout: usesCompactPopoverLayout
            )
                .presentationCompactAdaptation(.popover)
        }
        .sheet(isPresented: $isShowingRatingSheet) {
            ArtistRatingPalette(
                artist: artist,
                forcesCompactLayout: verticalSizeClass == .compact
            )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )
                .padding(.top, 12)
                .presentationDetents([.large])
        }
    }

    private var usesSheetPresentation: Bool {
        presentationLayout == .sheet
    }

    private var usesCompactPopoverLayout: Bool {
        presentationLayout == .compactPopover
    }

    private func presentationLayout(
        triggerMaxY: CGFloat
    ) -> PresentationLayout {
        guard !dynamicTypeSize.isAccessibilitySize,
              verticalSizeClass != .compact,
              viewportHeight > 0
        else {
            return .sheet
        }

        let availableSpaceBelow = max(viewportHeight - triggerMaxY, 0)
        if availableSpaceBelow < Layout.minimumCompactPopoverSpace {
            return .sheet
        }
        if availableSpaceBelow < Layout.minimumRegularPopoverSpace {
            return .compactPopover
        }
        return .regularPopover
    }

    private var triggerBackgroundColor: Color {
        rating == 0 ? Color.black.opacity(0.65) : Color.red
    }

    @ViewBuilder
    private var triggerIcon: some View {
        if rating > 0 {
            CompactRatingGlyph(
                rating: rating,
                iconName: settings.likeIcon,
                color: .white,
                size: Layout.iconSize,
                spread: 6,
                haloColor: .red
            )
        } else if let artistIcon {
            Image(systemName: artistIcon)
                .font(.system(size: Layout.iconSize, weight: .semibold))
        } else {
            Image(
                systemName: ArtistRatingOptions.baseSymbolName(
                    for: settings.likeIcon
                )
            )
            .font(.system(size: Layout.iconSize, weight: .semibold))
        }
    }

    private var triggerAccessibilityValue: String {
        guard let artistIcon else {
            return ArtistRatingOptions.localizedCurrentValue(
                for: rating,
                iconName: settings.likeIcon
            )
        }

        return String.localizedStringWithFormat(
            NSLocalizedString(
                "artist.rating.icon_picker.selected",
                comment: "Selected alternative artist rating"
            ),
            ArtistRatingOptions.localizedAlternativeLabel(for: artistIcon)
        )
    }
}

private struct ArtistRatingPalette: View {
    private enum Layout {
        static let regularContentWidth: CGFloat = 250
        static let accessibilityContentWidth: CGFloat = 260
        static let compactContentWidth: CGFloat = 220
        static let positiveButtonSize: CGFloat = 52
        static let positiveIconSize: CGFloat = 31
        static let compactPositiveButtonSize: CGFloat = 44
        static let compactPositiveIconSize: CGFloat = 27
        static let regularMarkerWidth: CGFloat = 78
        static let regularMarkerHeight: CGFloat = 68
        static let accessibilityMarkerHeight: CGFloat = 84
        static let compactMarkerSize: CGFloat = 44
        static let markerSpacing: CGFloat = 8
    }

    let artist: Artist
    let forcesCompactLayout: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var profile: FestivalProfileStore

    private var rating: Int {
        profile.rating(for: artist.id)
    }

    private var artistIcon: String? {
        guard rating < 0 else {
            return nil
        }

        return profile.iconName(forArtistID: artist.id)
            ?? ArtistRatingOptions.defaultAlternativeIcon
    }

    private func contentWidth(compact: Bool) -> CGFloat {
        if compact {
            return Layout.compactContentWidth
        }

        return dynamicTypeSize.isAccessibilitySize
            ? Layout.accessibilityContentWidth
            : Layout.regularContentWidth
    }

    private func markerWidth(compact: Bool) -> CGFloat {
        if compact {
            return Layout.compactMarkerSize
        }

        guard dynamicTypeSize.isAccessibilitySize else {
            return Layout.regularMarkerWidth
        }

        return (
            contentWidth(compact: false) - Layout.markerSpacing
        ) / 2
    }

    private func markerHeight(compact: Bool) -> CGFloat {
        if compact {
            return Layout.compactMarkerSize
        }

        return dynamicTypeSize.isAccessibilitySize
            ? Layout.accessibilityMarkerHeight
            : Layout.regularMarkerHeight
    }

    private func markerColumnCount(compact: Bool) -> Int {
        if compact {
            return 3
        }

        return dynamicTypeSize.isAccessibilitySize ? 2 : 3
    }

    private func positiveButtonSize(compact: Bool) -> CGFloat {
        compact
            ? Layout.compactPositiveButtonSize
            : Layout.positiveButtonSize
    }

    private func positiveIconSize(compact: Bool) -> CGFloat {
        compact
            ? Layout.compactPositiveIconSize
            : Layout.positiveIconSize
    }

    private func contentSpacing(compact: Bool) -> CGFloat {
        compact ? 6 : 14
    }

    private func contentPadding(compact: Bool) -> CGFloat {
        compact ? 10 : 16
    }

    private func markerColumns(compact: Bool) -> [GridItem] {
        Array(
            repeating: GridItem(
                .fixed(markerWidth(compact: compact)),
                spacing: Layout.markerSpacing
            ),
            count: markerColumnCount(compact: compact)
        )
    }

    @ViewBuilder
    var body: some View {
        if
            forcesCompactLayout
                || verticalSizeClass == .compact
        {
            paletteContent(compact: true)
        } else {
            paletteContent(compact: false)
        }
    }

    private func paletteContent(compact: Bool) -> some View {
        VStack(
            alignment: .leading,
            spacing: contentSpacing(compact: compact)
        ) {
            HStack(spacing: 8) {
                Text("artist.rating.menu")
                    .font(.headline)
                    .accessibilityHeading(.h2)

                Spacer(minLength: 0)

                if rating != 0 {
                    Button {
                        profile.setArtistRating(for: artist, rating: 0)
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("artist.rating.reset"))
                }
            }

            HStack {
                Spacer(minLength: 0)

                PositiveArtistRatingPicker(
                    rating: rating,
                    iconName: settings.likeIcon,
                    buttonSize: positiveButtonSize(compact: compact),
                    iconSize: positiveIconSize(compact: compact)
                ) { selectedRating in
                    profile.setArtistRating(
                        for: artist,
                        rating: selectedRating
                    )
                    dismiss()
                }
                .padding(3)
                .background(
                    Color.secondary.opacity(0.08),
                    in: Capsule()
                )

                Spacer(minLength: 0)
            }

            Divider()

            Text("artist.rating.icon_picker")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHeading(.h3)

            LazyVGrid(
                columns: markerColumns(compact: compact),
                spacing: Layout.markerSpacing
            ) {
                ForEach(ArtistRatingOptions.alternativeIcons, id: \.self) { icon in
                    markerButton(for: icon, compact: compact)
                }
            }
        }
        .frame(width: contentWidth(compact: compact))
        .padding(contentPadding(compact: compact))
    }

    private func markerButton(for icon: String, compact: Bool) -> some View {
        let isSelected = artistIcon == icon
        let label = ArtistRatingOptions.localizedAlternativeLabel(for: icon)

        return Button {
            profile.setArtistIcon(for: artist, icon: icon)
            dismiss()
        } label: {
            VStack(spacing: compact ? 0 : 5) {
                Image(systemName: icon)
                    .font(
                        .system(
                            size: compact ? 19 : 21,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        isSelected ? Color.accentColor : Color.secondary
                    )

                if !compact {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(
                            isSelected ? Color.accentColor : Color.primary
                        )
                        .multilineTextAlignment(.center)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(
                width: markerWidth(compact: compact),
                height: markerHeight(compact: compact)
            )
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.12)
                    : Color.secondary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.accentColor.opacity(0.45)
                            : Color.clear,
                        lineWidth: 1
                    )
            }
            .contentShape(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PositiveArtistRatingPicker: View {
    let rating: Int
    let iconName: String
    let buttonSize: CGFloat
    let iconSize: CGFloat
    let setRating: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...3, id: \.self) { option in
                ratingButton(for: option)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func ratingButton(for option: Int) -> some View {
        let isFilled = rating > 0 && rating >= option
        let isSelected = rating == option

        return Button {
            setRating(option)
        } label: {
            Image(systemName: ArtistRatingOptions.baseSymbolName(for: iconName))
                .symbolVariant(isFilled ? .fill : .none)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(isFilled ? Color.red : Color.secondary)
                .frame(width: buttonSize, height: buttonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                ArtistRatingOptions.localizedPositiveLabel(
                    for: option,
                    iconName: iconName
                )
            )
        )
        .accessibilityValue(
            Text(
                ArtistRatingOptions.localizedCurrentValue(
                    for: rating,
                    iconName: iconName
                )
            )
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    ArtistRatingPopoverButton(
        artist: .example,
        currentTipID: nil
    )
    .environmentObject(UserSettings())
    .environmentObject(FestivalProfileStore(cloudKitEnabled: false))
}
