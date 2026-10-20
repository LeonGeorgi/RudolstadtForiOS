import SwiftUI

struct ProgramDiscoveryView: View {
    let tagID: Int?

    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var friends: FriendProfilesStore
    @EnvironmentObject private var settings: UserSettings

    private var availableTags: [Tag] {
        let tags = festivalData.events.flatMap(\.tags)
        return ["Workshop", "Tanzworkshop", "Vortrag", "Mitmachtanz", "Tanzabend",
                "Kindertanz", "Film", "Ausstellung", "Länderschwerpunkt", "EBU", "RUTH"]
            .compactMap { name in tags.first { $0.germanName == name } }
    }

    private var selectedTag: Tag? {
        festivalData.events.lazy.flatMap(\.tags).first { $0.id == tagID }
    }

    private var events: [Event] {
        festivalData.events.filter { event in
            event.tags.contains { $0.id == tagID }
        }.sorted(by: Event.precedes)
    }

    private var introduction: LocalizedStringKey? {
        switch selectedTag?.germanName {
        case "Länderschwerpunkt": "program.discovery.country.intro"
        case "EBU": "program.discovery.ebu.intro"
        case "RUTH": "program.discovery.ruth.intro"
        default: nil
        }
    }

    private func title(for tag: Tag) -> String {
        tag.germanName == "Mitmachtanz"
            ? String(localized: "program.discovery.dance-along")
            : (tag.localizedName.isEmpty ? tag.germanName : tag.localizedName)
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
                        title(for: tag),
                        value: AppNavigationRoute.programDiscovery(tagID: tag.id)
                    )
                }
            } else {
                if let introduction {
                    Section {
                        Text(introduction)
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
            selectedTag.map { title(for: $0) }
                ?? String(localized: "program.discovery.title")
        )
    }
}
