import SwiftUI

struct ArtistEventsBlock: View {
    private enum Layout {
        static let regularTimeBadgeSize: CGFloat = 48
        static let accessibilityTimeBadgeSize: CGFloat = 52
    }

    let artistEvents: [Event]
    let highlightedEventId: Int?
    let currentTipID: String?
    let navigate: ((AppNavigationRoute) -> Void)?
    
    @Environment(\.artistDetailTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var dataStore: DataStore

    private var timeBadgeSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? Layout.accessibilityTimeBadgeSize
            : Layout.regularTimeBadgeSize
    }
    
    private func intersectingEventsByArtistEvent(
        _ artistEvents: [Event]
    ) -> [Int: [Event]] {
        let savedEventIDs = Set(profile.savedEvents)
        let estimatedEventDurations = dataStore.estimatedEventDurationsByEventID ?? [:]
        
        let savedEvents = festivalData.events.filter { savedEventIDs.contains($0.id) }
        
        var results: [Int: [Event]] = [:]
        results.reserveCapacity(artistEvents.count)
        
        for artistEvent in artistEvents {
            let intersectingEvents = savedEvents.filter { savedEvent in
                savedEvent.artist.id != artistEvent.artist.id
                && savedEvent.intersects(
                    with: artistEvent,
                    event1Duration: estimatedEventDurations[savedEvent.id] ?? 60,
                    event2Duration: estimatedEventDurations[artistEvent.id] ?? 60,
                    maxAllowedMissedMinutes: 5
                )
            }
            results[artistEvent.id] = intersectingEvents
        }
        
        return results
    }
    
    var body: some View {
        if artistEvents.isEmpty {
            EmptyView()
        } else {
            eventsContent
        }
    }
    
    private var eventsContent: some View {
        let intersectionsByEventID = intersectingEventsByArtistEvent(artistEvents)
        
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(artistEvents.enumerated()), id: \.element.id) { index, event in
                let isSaved = profile.isEventSaved(event.id)
                let friendProfiles = profile.friendProfilesSavingEvent(event.id)
                let route = AppNavigationRoute.stage(
                    id: event.stage.id,
                    highlightedEventId: event.id
                )

                HStack(spacing: 0) {
                    NavigationLink(value: route) {
                        ArtistEventCell(
                            event: event,
                            intersectingEvents: intersectionsByEventID[event.id] ?? [],
                            isSaved: isSaved,
                            friendProfilesWhoSavedEvent: friendProfiles,
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
                    if highlightedEventId == event.id && artistEvents.count > 1 {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.actionSurface)
                    }
                }
                
                if index < artistEvents.count - 1 {
                    Divider()
                        .overlay(theme.separator)
                        .padding(
                            .leading,
                            timeBadgeSize
                                + (dynamicTypeSize.isAccessibilitySize ? 12 : 10)
                        )
                }
                
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
                    navigate: nil
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
