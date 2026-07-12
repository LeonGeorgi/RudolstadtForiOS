import SwiftUI

struct ArtistEventsBlock: View {
    let artistEvents: [Event]
    let highlightedEventId: Int?
    let currentTipID: String?
    let navigate: ((AppNavigationRoute) -> Void)?
    
    @Environment(\.artistDetailTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var dataStore: DataStore
    
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
                NavigationLink(
                    value: AppNavigationRoute.stage(
                        id: event.stage.id,
                        highlightedEventId: event.id
                    )
                ) {
                    ArtistEventCell(
                        event: event,
                        intersectingEvents: intersectionsByEventID[event.id] ?? [],
                        isSaved: profile.isEventSaved(event.id),
                        friendProfilesWhoSavedEvent: profile.friendProfilesSavingEvent(event.id),
                        onToggleSaved: { profile.toggleSavedEvent(event) }
                    )
                    .environment(\.artistNavigationHandler, navigate)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        highlightedEventId == event.id && artistEvents.count > 1
                        ? theme.actionSurface
                        : Color.clear
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if index < artistEvents.count - 1 {
                    Divider()
                        .overlay(theme.separator)
                        .padding(
                            .leading,
                            dynamicTypeSize.isAccessibilitySize ? 16 : 16 + 52 + 10
                        )
                }
                
            }
        }
        .padding(.vertical, 8)
        .background(theme.eventSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
