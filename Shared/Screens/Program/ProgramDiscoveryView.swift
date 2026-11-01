import SwiftUI

struct ProgramDiscoveryView: View {
    let tagID: String?

    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var friends: FriendProfilesStore
    @EnvironmentObject private var settings: UserSettings

    private var availableTags: [Tag] {
        festivalData.features.eventDetails.value?.tags.filter(\.isDiscoverable) ?? []
    }

    private var selectedTag: Tag? {
        festivalData.features.eventDetails.value?.tags.first { $0.id == tagID }
    }

    private var events: [Event] {
        guard let tagID else { return [] }
        return festivalData.events.filter { event in
            festivalData.features.eventDetails.value?.details(for: event.id)?.tags.contains { $0.id == tagID } == true
        }.sorted(by: Event.precedes)
    }

    var body: some View {
        List {
            if tagID == nil {
                if availableTags.isEmpty {
                    Text("program.discovery.empty")
                        .foregroundStyle(.secondary)
                }
                ForEach(availableTags) { tag in
                    NavigationLink(
                        tag.title.resolved(),
                        value: AppNavigationRoute.programDiscovery(tagID: tag.id)
                    )
                }
            } else {
                if let introduction = selectedTag?.introduction {
                    Section {
                        Text(introduction.resolved())
                            .foregroundStyle(.secondary)
                    }
                }
                let grouped = Dictionary(grouping: events, by: \.festivalDate)
                let days = grouped.keys.sorted {
                    ($0 ?? .distantFuture) < ($1 ?? .distantFuture)
                }
                ForEach(days, id: \.self) { day in
                    Section {
                        ForEach(grouped[day] ?? []) { event in
                            NavigationLink(
                                value: AppNavigationRoute.artist(
                                    id: event.artist.id, highlightedEventId: event.id,
                                    transitionSourceID: nil
                                )
                            ) {
                                ScheduleEventCell(
                                    event: event,
                                    contextPreviewState: EventContextPreviewState(
                                        event: event, profile: profile, friends: friends,
                                        settings: settings
                                    ),
                                    onToggleSaved: { profile.toggleSavedEvent(event) }
                                )
                            }
                        }
                    } header: {
                        if let day {
                            Text(FestivalDateUtilities.format(day, pattern: "EEEE, dd.MM."))
                        } else {
                            Text("event.date.unknown")
                        }
                    }
                }
                if events.isEmpty {
                    Text("schedule.empty.description")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(
            selectedTag?.title.resolved()
                ?? String(localized: "program.discovery.title")
        )
    }
}
