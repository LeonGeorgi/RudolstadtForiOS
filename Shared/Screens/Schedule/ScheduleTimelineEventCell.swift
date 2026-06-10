import SwiftUI

struct ScheduleTimelineEventCell: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.displayScale) var displayScale
    let width: CGFloat
    let height: CGFloat
    let event: Event
    let eventDurationMinutes: Int
    let isSaved: Bool
    let artistRating: Int
    let artistIconName: String?
    let friendProfilesWhoSavedEvent: [SharedFestivalProfile]
    let onToggleSaved: () -> Void
    private let cornerRadius: CGFloat = 8

    var body: some View {
        renderContent()
            .contextMenu {
                SaveEventButton(event: event, isSaved: isSaved, onToggle: onToggleSaved)
            } preview: {
                SaveEventPreview(event: event)
            }
    }

    func renderContent() -> some View {
        let baseColor = getColorForEvent(event)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return NavigationLink(
            value: AppNavigationRoute.artist(
                id: event.artist.id,
                highlightedEventId: event.id,
                transitionSourceID: nil
            )
        ) {
            VStack(alignment: .center, spacing: 1) {
                if hasVisibleTag, let tag = event.tag {
                    Text(tag.localizedName)
                        //.frame(maxWidth: width)
                        .font(.system(size: 7, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(cellSecondaryForegroundColor.opacity(0.78))
                        .padding(.top, 3)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                }

                Text(event.artist.formattedName)
                    //.frame(maxWidth: width)
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(cellForegroundColor)
                    .lineLimit(2)
                    .lineSpacing(0)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 1)
                    .padding(.top, hasVisibleTag ? 0 : 3)
                Spacer(minLength: 0)

            }
            .padding(.bottom, showsFooterIndicators ? 14 : 0)
            .padding(.horizontal, 4)
            .frame(width: width, height: height)
            .background(
                shape
                    .fill(baseColor)
            )
            .overlay {
                shape
                    .strokeBorder(cellBorderColor(for: event), lineWidth: cellBorderWidth)
            }
            .overlay(alignment: .bottom) {
                footerIndicators
            }
        }
        .buttonStyle(.plain)
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

    private let footerHorizontalPadding: CGFloat = 3
    private let footerIndicatorGap: CGFloat = 2
    private let footerIndicatorHeight: CGFloat = 17

    private var footerIndicatorSideWidth: CGFloat {
        max((width - footerHorizontalPadding * 2 - footerIndicatorGap) / 2, 0)
    }

    private var cellForegroundColor: Color {
        .primary.opacity(colorScheme == .light ? 1 : 0.9)
    }

    private var cellSecondaryForegroundColor: Color {
        .secondary
    }

    private func cellBorderColor(for event: Event) -> Color {
        guard isSaved else {
            return Color.okhsl(
                h: event.artist.artistType.okhslHue,
                s: normalBorderSaturation,
                l: normalBorderLightness
            )
            .opacity(normalBorderOpacity)
        }

        return Color.okhsl(
            h: event.artist.artistType.okhslHue,
            s: savedBorderSaturation,
            l: savedBorderLightness
        )
        .opacity(0.96)
    }

    private var cellBorderWidth: CGFloat {
        let pixelWidth = 1 / max(displayScale, 1)
        return isSaved ? pixelWidth * 2 : pixelWidth
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
        if colorScheme == .dark {
            return isSaved ? 0.48 : 0.2
        }

        return isSaved ? 0.48 : 0.3
    }

    private var scheduleColorLightness: Double {
        if colorScheme == .dark {
            return isSaved ? 0.38 : 0.2
        }

        return isSaved ? 0.86 : 0.95
    }

    private var savedBorderSaturation: Double {
        if colorScheme == .dark {
            return 0.36
        }

        return 0.38
    }

    private var savedBorderLightness: Double {
        if colorScheme == .dark {
            return 0.72
        }

        return 0.62
    }

    private var normalBorderSaturation: Double {
        if colorScheme == .dark {
            return 0.26
        }

        return 0.24
    }

    private var normalBorderLightness: Double {
        if colorScheme == .dark {
            return 0.46
        }

        return 0.72
    }

    private var normalBorderOpacity: Double {
        colorScheme == .dark ? 0.48 : 0.42
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
            eventDurationMinutes: 60,
            isSaved: previewCase.isSaved,
            artistRating: previewCase.artistRating,
            artistIconName: previewCase.artistIconName,
            friendProfilesWhoSavedEvent: previewCase.friendProfilesWhoSavedEvent,
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
