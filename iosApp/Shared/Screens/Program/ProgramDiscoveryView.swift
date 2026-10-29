import SwiftUI

struct ProgramDiscoveryView: View {
    let tagID: String?

    @Environment(\.festivalData) private var festivalData
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var friends: FriendProfilesStore
    @EnvironmentObject private var settings: UserSettings

    private var availableTags: [Tag] {
        festivalData.features.eventDetails.value?.tags.filter(\.isDiscoverable) ?? []
    }

    private var selectedTag: Tag? {
        festivalData.features.eventDetails.value?.tags.first { $0.id == tagID }
    }

    private var eventCounts: [String: Int] {
        var counts = [String: Int]()
        for event in festivalData.events {
            let tags = festivalData.features.eventDetails.value?.details(for: event.id)?.tags ?? []
            for id in Set(tags.map(\.id)) {
                counts[id, default: 0] += 1
            }
        }
        return counts
    }

    private var events: [Event] {
        guard let tagID else { return [] }
        return festivalData.events.filter { event in
            festivalData.features.eventDetails.value?.details(for: event.id)?.tags.contains { $0.id == tagID } == true
        }.sorted(by: Event.precedes)
    }

    var body: some View {
        Group {
            if tagID == nil {
                tagOverview
            } else {
                eventList
            }
        }
        .navigationTitle(
            selectedTag?.title.resolved()
                ?? String(localized: "program.discovery.title")
        )
    }

    private var tagOverview: some View {
        ScrollView {
            VStack {
                if availableTags.isEmpty {
                    Text("program.discovery.empty")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    let counts = eventCounts
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: 12, alignment: .topLeading),
                            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                        ),
                        spacing: 12
                    ) {
                        ForEach(availableTags) { tag in
                            NavigationLink(value: AppNavigationRoute.programDiscovery(tagID: tag.id)) {
                                ProgramDiscoveryTagTile(tag: tag, eventCount: counts[tag.id] ?? 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background {
            #if os(iOS)
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
            #else
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()
            #endif
        }
        #if os(iOS)
            .toolbarBackground(.automatic, for: .navigationBar)
        #endif
    }

    private var eventList: some View {
        List {
            if let introduction = selectedTag?.introduction {
                Section {
                    Text(introduction.resolved())
                        .foregroundStyle(.secondary)
                }
            }
            if let editorialContent = selectedTag?.editorialContent {
                ProgramEditorialSections(content: editorialContent)
            }
            let grouped = Dictionary(grouping: events, by: \.festivalDate)
            let days = grouped.keys.sorted {
                ($0 ?? .distantFuture) < ($1 ?? .distantFuture)
            }
            ForEach(days, id: \.self) { day in
                Section {
                    ForEach(grouped[day] ?? []) { event in
                        NavigationLink(
                            value: AppNavigationRoute.festival(.event(event.id))
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
}

private struct ProgramDiscoveryTagTile: View {
    let tag: Tag
    let eventCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tag.title.resolved())
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)

            HStack(alignment: .firstTextBaseline) {
                count
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var count: some View {
        Text(
            eventCount == 1
                ? String(localized: "program.discovery.event-count.one")
                : String(
                    format: String(localized: "program.discovery.event-count.other"),
                    Int64(eventCount))
        )
        .font(.subheadline)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Used for both category introductions and information specific to one event.
private struct ProgramEditorialSections: View {
    let content: FestivalEditorialContent

    private var articleText: String {
        guard let article = content.article else { return "" }
        let text = article.text.resolved()
        return (article.format == .html ? formatString(text) : text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        if !articleText.isEmpty {
            Section {
                Text(articleText)
                    .textSelection(.enabled)
            }
        }

        let fields = content.fields.filter(\.hasContent)
        if !fields.isEmpty {
            Section {
                ForEach(fields) { field in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(field.title.resolved())
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(field.value.resolved())
                            .font(.body)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                }
            }
        }

        let links = content.nativeLinks
        if !links.isEmpty {
            Section {
                ForEach(links) { link in
                    if link.openingMode == .inAppBrowser {
                        NavigationLink(link.title.resolved()) {
                            EmbeddedWebView(url: link.destination)
                        }
                    } else {
                        Link(link.title.resolved(), destination: link.destination)
                    }
                }
            }
        }
    }
}

struct ProgramEventDetailView: View {
    let event: Event
    let editorialContent: FestivalEditorialContent

    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var friends: FriendProfilesStore
    @EnvironmentObject private var settings: UserSettings

    var body: some View {
        List {
            Section {
                ScheduleEventCell(
                    event: event,
                    contextPreviewState: EventContextPreviewState(
                        event: event, profile: profile, friends: friends, settings: settings),
                    onToggleSaved: { profile.toggleSavedEvent(event) }
                )
            } header: {
                if let day = event.festivalDate {
                    Text(FestivalDateUtilities.format(day, pattern: "EEEE, dd.MM."))
                } else {
                    Text("event.date.unknown")
                }
            }

            ProgramEditorialSections(content: editorialContent)

            Section {
                NavigationLink(
                    value: AppNavigationRoute.artist(
                        id: event.artist.id, highlightedEventId: event.id, transitionSourceID: nil)
                ) {
                    Label(event.artist.formattedName, systemImage: "person.crop.square")
                }
                NavigationLink(
                    value: AppNavigationRoute.stage(id: event.stage.id, highlightedEventId: event.id)
                ) {
                    Label(event.stage.localizedName, systemImage: "mappin.and.ellipse")
                }
            } header: {
                Text("program.event.related")
            }
        }
        .navigationTitle(event.artist.formattedName)
    }
}
