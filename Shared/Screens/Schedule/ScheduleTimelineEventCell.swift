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

struct ScheduleTimelineEventCell: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.locale) private var locale
    let width: CGFloat
    let height: CGFloat
    let event: Event
    let contextPreviewState: EventContextPreviewState
    let onToggleSaved: () -> Void
    private let cornerRadius: CGFloat = 4

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
            .contextMenu {
                SaveEventButton(event: event, isSaved: isSaved, onToggle: onToggleSaved)
            } preview: {
                EventContextPreview(
                    event: event,
                    state: contextPreviewState
                )
            }
    }

    func renderContent() -> some View {
        let tintColor = getColorForEvent(event)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return NavigationLink(
            value: AppNavigationRoute.artist(
                id: event.artist.id,
                highlightedEventId: event.id,
                transitionSourceID: nil
            )
        ) {
            cardContent
                .padding(.bottom, showsFooterIndicators ? 14 : 0)
                .padding(.horizontal, horizontalContentPadding)
                .frame(width: width, height: height)
                .background(
                    shape
                        .fill(tintColor.opacity(scheduleColorOpacity))
                )
                .overlay(alignment: .bottom) {
                    footerIndicators
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: contentHorizontalAlignment, spacing: 1) {
            tagLabel

            if detailLevel == .compact {
                artistName
                    .padding(.top, hasVisibleTag ? 0 : 3)

                Spacer(minLength: 0)
            } else {
                VStack(alignment: contentHorizontalAlignment, spacing: 0) {
                    artistName
                        .layoutPriority(2)

                    if detailLevel >= .time {
                        metadataText(event.timeAsString, weight: .medium)
                            .monospacedDigit()
                            .padding(.top, 3)
                            .layoutPriority(1)
                    }

                    if detailLevel >= .origin, let originText {
                        metadataText(
                            originText,
                            lineLimit: originLineLimit
                        )
                            .padding(.top, 1)
                    }

                    if detailLevel >= .discovery, let tagsText {
                        metadataText(tagsText, weight: .medium, lineLimit: 2)
                            .padding(.top, 4)
                    }

                    if detailLevel >= .summary, let summaryText {
                        Text(summaryText)
                            .font(.system(size: 10))
                            .foregroundStyle(tertiaryForegroundColor)
                            .lineLimit(summaryLineLimit)
                            .lineSpacing(1.5)
                            .minimumScaleFactor(0.95)
                            .multilineTextAlignment(contentTextAlignment)
                            .frame(
                                maxWidth: .infinity,
                                alignment: contentFrameAlignment
                            )
                            .padding(.top, 5)
                    }
                }
                .padding(.top, hasVisibleTag ? 3 : detailedContentTopPadding)

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var tagLabel: some View {
        if hasVisibleTag, let tag = event.tag {
            Text(tag.localizedName(locale: locale))
                .font(.system(size: 8.5, weight: .semibold))
                .frame(
                    maxWidth: .infinity,
                    alignment: contentFrameAlignment
                )
                .foregroundColor(tagForegroundColor)
                .padding(.top, 3)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(contentTextAlignment)
        }
    }

    private var artistName: some View {
        Text(event.artist.formattedName)
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
            .foregroundColor(cellForegroundColor)
            .lineLimit(2)
            .lineSpacing(1)
            .minimumScaleFactor(usesLeadingLayout ? 0.85 : 0.75)
            .multilineTextAlignment(contentTextAlignment)
            .padding(.vertical, 1)
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
            .minimumScaleFactor(0.9)
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
        case .compact:
            return 4
        case .time:
            return 5
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

    private var originText: String? {
        let countries = localizedArtistCountries(
            rawValue: event.artist.countries,
            countryCodes: event.artist.countryCodes,
            locale: locale
        )
        let countryFormatter = ListFormatter()
        countryFormatter.locale = locale
        let country = countryFormatter.string(from: countries.map(\.name))

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

    private var tagsText: String? {
        var seen = Set<String>()
        let tags = event.artist.ai?.localizedTags(locale: locale)
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

    private var summaryText: String? {
        let summary = event.artist.ai?.localizedSummary(locale: locale)
        return summary?.isEmpty == false ? summary : nil
    }

    private var friendSavedBadges: FriendSavedEventBadges {
        FriendSavedEventBadges(
            eventID: event.id,
            profiles: friendProfilesWhoSavedEvent,
            style: .plainFooter
        )
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
            .padding(.bottom, 3)
            .frame(maxWidth: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var footerRatingIndicator: some View {
        if artistRating != 0 {
            ArtistRatingSymbol(rating: artistRating, iconName: artistIconName)
                .font(.system(size: 10.8))
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
            friendSavedBadges
        }
    }

    private var showsFooterIndicators: Bool {
        artistRating != 0 || !friendProfilesWhoSavedEvent.isEmpty
    }

    private let footerIndicatorGap: CGFloat = 2
    private let footerIndicatorHeight: CGFloat = 17

    private var footerHorizontalPadding: CGFloat {
        horizontalContentPadding
    }

    private var footerIndicatorSideWidth: CGFloat {
        max((width - footerHorizontalPadding * 2 - footerIndicatorGap) / 2, 0)
    }

    private var cellForegroundColor: Color {
        if isSaved {
            return colorScheme == .dark ? .black : .white
        }

        return .primary.opacity(colorScheme == .light ? 1 : 0.9)
    }

    private var cellSecondaryForegroundColor: Color {
        isSaved ? cellForegroundColor : .secondary
    }

    private var metadataForegroundColor: Color {
        let opacity = isSaved
            ? 0.82
            : (colorScheme == .light ? 0.68 : 0.78)
        return cellForegroundColor.opacity(opacity)
    }

    private var tertiaryForegroundColor: Color {
        metadataForegroundColor.opacity(0.9)
    }

    private var tagForegroundColor: Color {
        metadataForegroundColor.opacity(0.9)
    }

    private var savedRatingHaloColor: Color {
        guard isSaved else {
            return .clear
        }

        return colorScheme == .dark
            ? .black.opacity(0.45)
            : .white.opacity(0.8)
    }

    private var hasVisibleTag: Bool {
        guard let tag = event.tag else {
            return false
        }

        return !tag.isStageOrBuskers
    }

    func getColorForEvent(_ event: Event) -> Color {
        Color.okhsl(
            h: event.artist.artistType.okhslHue,
            s: scheduleColorSaturation,
            l: scheduleColorLightness
        )
    }

    private var scheduleColorSaturation: Double {
        colorScheme == .dark ? 0.35 : 0.64
    }

    private var scheduleColorLightness: Double {
        if isSaved {
            return colorScheme == .dark ? 0.75 : 0.45
        }

        if colorScheme == .dark {
            return 0.21
        }

        return 0.85
    }

    private var scheduleColorOpacity: Double {
        if isSaved {
            return 1
        }

        if colorScheme == .dark {
            return 0.88
        }

        return 0.4
    }
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
            badgeColorHex: "#B54E9B",
            festivalYear: DataStore.year,
            savedEventIDs: [],
            artistPreferences: []
        ),
        SharedFestivalProfile(
            id: "timeline-sam",
            title: "Sam's weekend",
            ownerName: "Sam",
            badgeName: "Sam",
            badgeColorHex: "#23867A",
            festivalYear: DataStore.year,
            savedEventIDs: [],
            artistPreferences: []
        ),
        SharedFestivalProfile(
            id: "timeline-jo",
            title: "Jo's route",
            ownerName: "Jo",
            badgeName: "Jo",
            badgeColorHex: "#D49A1F",
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
        Artist(
            id: id,
            hiddenFromArtistList: Artist.example.hiddenFromArtistList,
            artistType: artistType,
            someNumber: Artist.example.someNumber,
            name: name,
            countries: Artist.example.countries,
            countryCodes: Artist.example.countryCodes,
            url: Artist.example.url,
            facebookID: Artist.example.facebookID,
            youtubeID: Artist.example.youtubeID,
            instagram: Artist.example.instagram,
            descriptionGerman: Artist.example.descriptionGerman,
            descriptionEnglish: Artist.example.descriptionEnglish,
            thumbImageUrlString: Artist.example.thumbImageUrlString,
            fullImageUrlString: Artist.example.fullImageUrlString,
            ai: Artist.example.ai
        )
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
        ScheduleTimelineEventCell(
            width: 60,
            height: 60,
            event: previewCase.event,
            contextPreviewState: EventContextPreviewState(
                isSaved: previewCase.isSaved,
                artistRating: previewCase.artistRating,
                artistIconName: previewCase.artistIconName,
                friendProfilesWhoSavedEvent:
                    previewCase.friendProfilesWhoSavedEvent,
                artistNote: nil,
                isArtistSummaryEnabled: true
            ),
            onToggleSaved: {}
        )
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
