import SwiftUI
import RudolstadtCore

struct ArtistEventsBlock: View {
    private enum Layout {
        static let regularTimeBadgeSize: CGFloat = 48
        static let accessibilityTimeBadgeSize: CGFloat = 52
    }

    let artistEvents: [Event]
    let highlightedEventId: Int?
    let currentTipID: String?
    let navigate: ((AppNavigationRoute) -> Void)?
    let horizontalHighlightBleed: CGFloat

    @Environment(\.artistDetailTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var friends: FriendProfilesStore
    @EnvironmentObject private var settings: UserSettings

    private var timeBadgeSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? Layout.accessibilityTimeBadgeSize
            : Layout.regularTimeBadgeSize
    }

    private func intersectingEventsByArtistEvent(
        _ artistEvents: [Event]
    ) -> [Int: [Event]] {
        Dictionary(
            uniqueKeysWithValues: festivalData.programDetails.conflicts(
                id: artistEvents.first?.artist.artistID ?? 0,
                saved: Set(KotlinCore.ids(profile.savedEvents))
            ).map { (Int($0.eventID), $0.events) })
    }

    var body: some View {
        if !artistEvents.isEmpty {
            eventsContent
        }
    }

    private var eventsContent: some View {
        let intersectionsByEventID = intersectingEventsByArtistEvent(artistEvents)

        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(artistEvents.enumerated()), id: \.element.id) { index, event in
                let isSaved = profile.isEventSaved(event.id)
                let isHighlighted =
                    highlightedEventId == event.id
                let route = festivalData.eventDestination(
                    event, fallback: .stage(id: event.stage.id, highlightedEventId: event.id),
                    alwaysShowDetails: settings.alwaysShowEventDetails)

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        NavigationLink(value: route) {
                            ArtistEventCell(
                                event: event,
                                intersectingEvents: intersectionsByEventID[event.id] ?? [],
                                contextPreviewState: EventContextPreviewState(
                                    event: event,
                                    profile: profile,
                                    friends: friends,
                                    settings: settings
                                ),
                                showsTrailingAccessories: false,
                                timeBadgeSize: timeBadgeSize,
                                onToggleSaved: { profile.toggleSavedEvent(event) }
                            )
                            .environment(\.artistNavigationHandler, navigate)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        EventSavedIcon(
                            event: event,
                            isSaved: isSaved,
                            onToggle: { profile.toggleSavedEvent(event) }
                        )

                        NavigationLink(value: route) {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary.opacity(0.75))
                                .frame(width: 20, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHidden(true)
                    }
                    .padding(
                        .vertical,
                        dynamicTypeSize.isAccessibilitySize ? 10 : 4
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        if isHighlighted {
                            Color.rudolstadt
                                .opacity(0.10)
                                .padding(.horizontal, -horizontalHighlightBleed)
                        }
                    }
                    .accessibilityAddTraits(isHighlighted ? .isSelected : [])

                    if index < artistEvents.count - 1 {
                        Divider()
                            .overlay(theme.separator)
                            .padding(
                                .leading,
                                timeBadgeSize + FestivalListRowStyle.columnSpacing
                            )
                    }
                }
                .id(event.id)

            }
        }
    }
}

#if DEBUG
struct ArtistEventsBlock_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        let environment = PreviewMockData.makeEnvironment(
            suiteName: "ArtistEventsBlockPreview"
        )
        let artist = PreviewMockData.featuredArtist
        let artistEvents = environment.festivalData.events.filter { event in
            event.artist.id == artist.id
        }

        NavigationStack {
            ScrollView {
                ArtistEventsBlock(
                    artistEvents: artistEvents,
                    highlightedEventId: artistEvents.first?.id,
                    currentTipID: nil,
                    navigate: nil,
                    horizontalHighlightBleed: 16
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(.red.opacity(0.4))
            .navigationDestination(for: AppNavigationRoute.self) { _ in
                EmptyView()
            }
        }
        .previewEnvironment(environment)
    }
}
#endif
