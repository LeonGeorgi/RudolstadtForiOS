import Foundation
import SwiftUI

enum ScheduleTimelineEventCellDetailLevel: Int, Comparable {
    case compact
    case time
    case origin
    case discovery
    case summary

    init(width: CGFloat, height: CGFloat) {
        switch (width, height) {
        case (128..., 168...):
            self = .summary
        case (70..., 148...):
            self = .discovery
        case (64..., 104...):
            self = .origin
        case (54..., 84...):
            self = .time
        default:
            self = .compact
        }
    }

    static func < (
        lhs: ScheduleTimelineEventCellDetailLevel,
        rhs: ScheduleTimelineEventCellDetailLevel
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Native display values, prepared when their source data or environment changes.
/// Zoom dimensions deliberately do not belong here.
struct ScheduleTimelineEventPresentation {
    let event: Event
    let duration: Int
    let contextPreviewState: EventContextPreviewState
    let artistName: String
    let navigationRoute: AppNavigationRoute
    let timeText: String
    let tagText: String?
    let originText: String?
    let tagsText: String?
    let summaryText: String?
    let backgroundColor: Color
    let foregroundColor: Color
    let secondaryForegroundColor: Color
    let metadataColor: Color
    let tertiaryColor: Color
    let ratingHaloColor: Color
    let friendSavedBadges: FriendSavedEventBadges

    init(
        event: Event, duration: Int, contextPreviewState: EventContextPreviewState,
        locale: Locale, colorScheme: ColorScheme, countryFormatter: ListFormatter
    ) {
        self.event = event
        self.duration = duration
        self.contextPreviewState = contextPreviewState
        artistName = event.artist.formattedName
        navigationRoute = .artist(
            id: event.artist.id, highlightedEventId: event.id, transitionSourceID: nil)
        timeText = event.timeAsString
        tagText = event.tag.flatMap { $0.showsOnTimeline ? $0.localizedName(locale: locale) : nil }
        originText = Self.originText(event: event, locale: locale, formatter: countryFormatter)
        tagsText = Self.tagsText(event: event, locale: locale)
        let summary = event.artist.summary(locale: locale)
        summaryText = summary?.isEmpty == false ? summary : nil

        let isSaved = contextPreviewState.isSaved
        let isDark = colorScheme == .dark
        backgroundColor = Color.okhsl(
            h: event.artist.artistType.okhslHue,
            s: isDark ? 0.35 : 0.64,
            l: isSaved ? (isDark ? 0.75 : 0.45) : (isDark ? 0.21 : 0.85)
        ).opacity(isSaved ? 1 : (isDark ? 0.88 : 0.4))
        foregroundColor = isSaved ? (isDark ? .black : .white) : .primary.opacity(isDark ? 0.9 : 1)
        secondaryForegroundColor = isSaved ? foregroundColor : .secondary
        metadataColor = foregroundColor.opacity(isSaved ? 0.82 : (isDark ? 0.78 : 0.68))
        tertiaryColor = metadataColor.opacity(0.9)
        ratingHaloColor = isSaved ? (isDark ? .black.opacity(0.45) : .white.opacity(0.8)) : .clear
        friendSavedBadges = FriendSavedEventBadges(
            eventID: event.id, profiles: contextPreviewState.friendProfilesWhoSavedEvent,
            style: .plainFooter)
    }

    private static func originText(event: Event, locale: Locale, formatter: ListFormatter)
        -> String?
    {
        let countries = localizedArtistCountries(
            rawValue: event.artist.countries,
            countryCodes: event.artist.countryCodes,
            locale: locale
        )
        let country = formatter.string(from: countries.map(\.name))

        var seenCountryCodes = Set<String>()
        let flags = countries.compactMap { country -> String? in
            guard
                let countryCode = country.countryCode,
                seenCountryCodes.insert(countryCode).inserted
            else {
                return nil
            }
            return emojiFlag(forRegionCode: countryCode)
        }
        .joined()

        let value = [flags, country]
            .compactMap { value in
                guard let value, !value.isEmpty else {
                    return nil
                }
                return value
            }
            .joined(separator: " ")
        return value.isEmpty ? nil : value
    }

    private static func tagsText(event: Event, locale: Locale) -> String? {
        var seen = Set<String>()
        let tags = event.artist.keywordLabels(locale: locale)?
            .compactMap { tag -> String? in
                let value = tag.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard !value.isEmpty, seen.insert(value).inserted else {
                    return nil
                }
                return value
            }
            .prefix(3)
            .joined(separator: " • ")
        return tags?.isEmpty == false ? tags : nil
    }

}

struct ScheduleTimelineEventCell: View {
    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject private var settings: UserSettings
    let width: CGFloat
    let height: CGFloat
    let presentation: ScheduleTimelineEventPresentation
    let onToggleSaved: () -> Void
    private let cornerRadius: CGFloat = 4

    private var event: Event { presentation.event }
    private var contextPreviewState: EventContextPreviewState { presentation.contextPreviewState }

    private var isSaved: Bool {
        contextPreviewState.isSaved
    }

    private var artistRating: Int {
        contextPreviewState.artistRating
    }

    private var artistIconName: String? {
        contextPreviewState.artistIconName
    }

    private var friendProfilesWhoSavedEvent: [SharedFestivalProfile] {
        contextPreviewState.friendProfilesWhoSavedEvent
    }

    var body: some View {
        renderContent()
            .eventContextMenu(
                event: event, state: contextPreviewState, onToggleSaved: onToggleSaved)
    }

    func renderContent() -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return NavigationLink(value: festivalData.eventDestination(event, fallback: presentation.navigationRoute, alwaysShowDetails: settings.alwaysShowEventDetails)) {
            cardContent
                .padding(.bottom, showsFooterIndicators ? footerIndicatorHeight + 8 : 0)
                .padding(.horizontal, horizontalContentPadding)
                .frame(width: width, height: height)
                .background(
                    shape
                        .fill(presentation.backgroundColor)
                )
                .overlay(alignment: .bottom) {
                    footerIndicators
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: contentHorizontalAlignment, spacing: 0) {
            tagLabel

            if detailLevel == .compact {
                artistName
                    .padding(.top, hasVisibleTag ? 2 : 4)

                Spacer(minLength: 0)
            } else {
                VStack(alignment: contentHorizontalAlignment, spacing: 0) {
                    artistName
                        .layoutPriority(2)

                    if detailLevel >= .time {
                        metadataText(presentation.timeText, weight: .medium)
                            .monospacedDigit()
                            .padding(.top, 4)
                            .layoutPriority(1)
                    }

                    if detailLevel >= .origin, let originText = presentation.originText {
                        metadataText(
                            originText,
                            lineLimit: originLineLimit
                        )
                        .padding(.top, detailLevel >= .discovery ? 8 : 4)
                    }

                    if detailLevel >= .discovery, let tagsText = presentation.tagsText {
                        metadataText(tagsText, weight: .medium, lineLimit: 2)
                            .padding(.top, 8)
                    }

                    if detailLevel >= .summary, let summaryText = presentation.summaryText {
                        Text(summaryText)
                            .font(.system(size: 10))
                            .foregroundStyle(tertiaryForegroundColor)
                            .lineLimit(summaryLineLimit)
                            .lineSpacing(1.5)
                            .multilineTextAlignment(contentTextAlignment)
                            .frame(
                                maxWidth: .infinity,
                                alignment: contentFrameAlignment
                            )
                            .padding(.top, 8)
                    }
                }
                .padding(.top, hasVisibleTag ? 2 : detailedContentTopPadding)

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var tagLabel: some View {
        if let tagText = presentation.tagText {
            Text(tagText)
                .font(.system(size: 8.5, weight: .semibold))
                .frame(
                    maxWidth: .infinity,
                    alignment: contentFrameAlignment
                )
                .foregroundStyle(tagForegroundColor)
                .padding(.top, 4)
                .textCase(.uppercase)
                .lineLimit(1)
                .multilineTextAlignment(contentTextAlignment)
        }
    }

    private var artistName: some View {
        Text(presentation.artistName)
            .font(
                .system(
                    size: usesLeadingLayout ? 13 : 11.5,
                    weight: usesLeadingLayout ? .semibold : .medium
                )
            )
            .frame(
                maxWidth: .infinity,
                alignment: contentFrameAlignment
            )
            .foregroundStyle(cellForegroundColor)
            .lineLimit(2)
            .lineSpacing(1)
            .truncationMode(.tail)
            .multilineTextAlignment(contentTextAlignment)
            .padding(.vertical, 0.5)
    }

    private func metadataText(
        _ text: String,
        weight: Font.Weight = .regular,
        lineLimit: Int = 1
    ) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: weight))
            .foregroundStyle(metadataForegroundColor)
            .lineLimit(lineLimit)
            .lineSpacing(1)
            .multilineTextAlignment(contentTextAlignment)
            .frame(
                maxWidth: .infinity,
                alignment: contentFrameAlignment
            )
    }

    private var detailLevel: ScheduleTimelineEventCellDetailLevel {
        ScheduleTimelineEventCellDetailLevel(width: width, height: height)
    }

    private var usesLeadingLayout: Bool {
        detailLevel >= .origin
    }

    private var contentHorizontalAlignment: HorizontalAlignment {
        usesLeadingLayout ? .leading : .center
    }

    private var contentFrameAlignment: Alignment {
        usesLeadingLayout ? .leading : .center
    }

    private var contentTextAlignment: TextAlignment {
        usesLeadingLayout ? .leading : .center
    }

    private var horizontalContentPadding: CGFloat {
        switch detailLevel {
        case .compact, .time:
            return 4
        case .origin, .discovery, .summary:
            return 8
        }
    }

    private var detailedContentTopPadding: CGFloat {
        detailLevel >= .discovery ? 8 : 6
    }

    private var summaryLineLimit: Int {
        height >= 210 ? 4 : 2
    }

    private var originLineLimit: Int {
        detailLevel >= .discovery ? 2 : 1
    }

    @ViewBuilder
    private var footerIndicators: some View {
        if showsFooterIndicators {
            HStack(alignment: .center, spacing: 0) {
                footerRatingIndicator
                    .frame(
                        width: footerIndicatorSideWidth,
                        height: footerIndicatorHeight,
                        alignment: .leading
                    )

                Spacer(minLength: footerIndicatorGap)

                footerFriendIndicator
                    .frame(
                        width: footerIndicatorSideWidth,
                        height: footerIndicatorHeight,
                        alignment: .trailing
                    )
            }
            .padding(.horizontal, footerHorizontalPadding)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var footerRatingIndicator: some View {
        if artistRating != 0 {
            Group {
                if artistRating > 0 {
                    CompactRatingGlyph(
                        rating: artistRating, iconName: settings.likeIcon,
                        color: .red, size: 12, spread: 2,
                        haloColor: savedRatingHaloColor)
                } else {
                    ArtistRatingSymbol(rating: artistRating, iconName: artistIconName)
                }
            }
            .font(.system(size: 10.8))
            .frame(width: footerIndicatorHeight, height: footerIndicatorHeight)
            .foregroundStyle(cellSecondaryForegroundColor)
            .shadow(
                color: savedRatingHaloColor,
                radius: isSaved ? 1.25 : 0
            )
        }
    }

    @ViewBuilder
    private var footerFriendIndicator: some View {
        if !friendProfilesWhoSavedEvent.isEmpty {
            presentation.friendSavedBadges
        }
    }

    private var showsFooterIndicators: Bool {
        artistRating != 0 || !friendProfilesWhoSavedEvent.isEmpty
    }

    private let footerIndicatorGap: CGFloat = 2
    private let footerIndicatorHeight: CGFloat = 16

    private var footerHorizontalPadding: CGFloat {
        horizontalContentPadding
    }

    private var footerIndicatorSideWidth: CGFloat {
        max((width - footerHorizontalPadding * 2 - footerIndicatorGap) / 2, 0)
    }

    private var cellForegroundColor: Color { presentation.foregroundColor }
    private var cellSecondaryForegroundColor: Color { presentation.secondaryForegroundColor }
    private var metadataForegroundColor: Color { presentation.metadataColor }
    private var tertiaryForegroundColor: Color { presentation.tertiaryColor }
    private var tagForegroundColor: Color { presentation.tertiaryColor }
    private var savedRatingHaloColor: Color { presentation.ratingHaloColor }
    private var hasVisibleTag: Bool { presentation.tagText != nil }

}

#if DEBUG
    private struct ScheduleTimelineEventCellPreviewCase: Identifiable {
        let title: String
        let event: Event
        let isSaved: Bool
        let artistRating: Int
        let artistIconName: String?
        let friendProfilesWhoSavedEvent: [SharedFestivalProfile]

        var id: String {
            title
        }
    }

    private struct ScheduleTimelineEventCellPreview: View {
        @Environment(\.locale) private var locale
        @Environment(\.colorScheme) private var colorScheme
        let previewCase: ScheduleTimelineEventCellPreviewCase

        var body: some View {
            let formatter = ListFormatter()
            formatter.locale = locale
            return ScheduleTimelineEventCell(
                width: 60,
                height: 60,
                presentation: ScheduleTimelineEventPresentation(
                    event: previewCase.event, duration: 60,
                    contextPreviewState: EventContextPreviewState(
                        isSaved: previewCase.isSaved,
                        artistRating: previewCase.artistRating,
                        artistIconName: previewCase.artistIconName,
                        friendProfilesWhoSavedEvent:
                            previewCase.friendProfilesWhoSavedEvent,
                        artistNote: nil,
                        isArtistSummaryEnabled: true
                    ),
                    locale: locale, colorScheme: colorScheme, countryFormatter: formatter
                ),
                onToggleSaved: {}
            )
        }
    }

    struct ScheduleTimelineEventCell_Previews: PreviewProvider {
        private struct PreviewVariant: Identifiable {
            let title: String
            let artistType: ArtistType
            let isSaved: Bool
            let hasTag: Bool
            let artistRating: Int
            let friendSaveCount: Int

            var id: String {
                title
            }
        }

        private static let variants: [PreviewVariant] = [
            PreviewVariant(
                title: "Stage / unsaved / plain",
                artistType: .stage,
                isSaved: false,
                hasTag: false,
                artistRating: 0,
                friendSaveCount: 0
            ),
            PreviewVariant(
                title: "Stage / saved / tag",
                artistType: .stage,
                isSaved: true,
                hasTag: true,
                artistRating: 1,
                friendSaveCount: 1
            ),
            PreviewVariant(
                title: "Dance / unsaved / rated",
                artistType: .dance,
                isSaved: false,
                hasTag: true,
                artistRating: 2,
                friendSaveCount: 0
            ),
            PreviewVariant(
                title: "Dance / saved / friends",
                artistType: .dance,
                isSaved: true,
                hasTag: false,
                artistRating: 0,
                friendSaveCount: 2
            ),
            PreviewVariant(
                title: "Street / unsaved / friend",
                artistType: .street,
                isSaved: false,
                hasTag: false,
                artistRating: 0,
                friendSaveCount: 1
            ),
            PreviewVariant(
                title: "Street / saved / full",
                artistType: .street,
                isSaved: true,
                hasTag: true,
                artistRating: 3,
                friendSaveCount: 2
            ),
            PreviewVariant(
                title: "Other / unsaved / tag",
                artistType: .other,
                isSaved: false,
                hasTag: true,
                artistRating: 0,
                friendSaveCount: 0
            ),
            PreviewVariant(
                title: "Other / saved / rated",
                artistType: .other,
                isSaved: true,
                hasTag: false,
                artistRating: -1,
                friendSaveCount: 1
            ),
        ]

        private static let visibleTag = Tag(
            id: 9001,
            germanName: "Workshop",
            englishName: "Workshop"
        )

        private static let friendProfiles = [
            SharedFestivalProfile(
                id: "timeline-maya",
                title: "Maya's picks",
                ownerName: "Maya",
                badgeName: "Maya",
                badgeHue: 345,
                festivalYear: DataStore.year,
                savedEventIDs: [],
                artistPreferences: []
            ),
            SharedFestivalProfile(
                id: "timeline-sam",
                title: "Sam's weekend",
                ownerName: "Sam",
                badgeName: "Sam",
                badgeHue: 165,
                festivalYear: DataStore.year,
                savedEventIDs: [],
                artistPreferences: []
            ),
            SharedFestivalProfile(
                id: "timeline-jo",
                title: "Jo's route",
                ownerName: "Jo",
                badgeName: "Jo",
                badgeHue: 75,
                festivalYear: DataStore.year,
                savedEventIDs: [],
                artistPreferences: []
            ),
        ]

        private static func previewArtist(
            artistType: ArtistType,
            id: Int,
            name: String
        ) -> Artist {
            var groups = Artist.example.groupIDs
            groups["artist-kind"] = [String(artistType.rawValue)]
            return Artist(
                id: id, name: name, isListed: !Artist.example.hiddenFromArtistList,
                details: Artist.example.details, groupIDs: groups,
                summaries: Artist.example.localizedSummaries)
        }

        private static func exampleEvent(
            variant: PreviewVariant,
            id: Int,
            dayInJuly: Int
        ) -> Event {
            Event(
                id: id,
                dayInJuly: dayInJuly,
                timeAsString: "17:00",
                stage: .example,
                artist: previewArtist(
                    artistType: variant.artistType,
                    id: id,
                    name: previewArtistName(for: variant)
                ),
                tag: variant.hasTag ? visibleTag : nil
            )
        }

        private static func previewArtistName(for variant: PreviewVariant) -> String {
            switch variant.artistType {
            case .stage:
                return variant.isSaved ? "Saved Stage Act" : "Stage Act"
            case .dance:
                return variant.isSaved ? "Saved Dance Crew" : "Dance Crew"
            case .street:
                return variant.isSaved ? "Saved Street Duo" : "Street Duo"
            case .other:
                return variant.isSaved ? "Saved Talk" : "Talk"
            }
        }

        private static func previewCase(
            variant: PreviewVariant,
            index: Int
        ) -> ScheduleTimelineEventCellPreviewCase {
            let event = exampleEvent(
                variant: variant,
                id: 9200 + index,
                dayInJuly: 3 + index / 4
            )

            return ScheduleTimelineEventCellPreviewCase(
                title: variant.title,
                event: event,
                isSaved: variant.isSaved,
                artistRating: variant.artistRating,
                artistIconName: variant.artistRating < 0
                    ? "questionmark.circle.fill"
                    : nil,
                friendProfilesWhoSavedEvent: Array(
                    friendProfiles.prefix(variant.friendSaveCount)
                )
            )
        }

        private static var previewCases: [ScheduleTimelineEventCellPreviewCase] {
            variants.enumerated().map { index, variant in
                previewCase(variant: variant, index: index)
            }
        }

        private static func previewCell(
            _ previewCase: ScheduleTimelineEventCellPreviewCase
        ) -> some View {
            ScheduleTimelineEventCellPreview(previewCase: previewCase)
        }

        private static func previewColumn(
            _ previewCase: ScheduleTimelineEventCellPreviewCase
        ) -> some View {
            VStack(spacing: 6) {
                previewCell(previewCase)

                Text(previewCase.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(width: 76, height: 42, alignment: .top)
            }
        }

        static var previews: some View {
            let columns = Array(
                repeating: GridItem(.fixed(84), spacing: 12, alignment: .top),
                count: 4
            )

            NavigationStack {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(previewCases) { previewCase in
                        previewColumn(previewCase)
                    }
                }
                .padding()
                .navigationDestination(for: AppNavigationRoute.self) { _ in
                    EmptyView()
                }
            }
            .previewMockEnvironment(suiteName: "ScheduleTimelineEventCellPreview")
            .previewLayout(PreviewLayout.sizeThatFits)
        }
    }
#endif
