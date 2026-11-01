import SwiftUI

struct ProgramDiscoveryView: View {
    let tagID: String?

    @Environment(\.festivalData) private var festivalData
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var friends: FriendProfilesStore
    @EnvironmentObject private var settings: UserSettings

    private var availableTags: [Tag] {
        festivalData.tags.filter(\.isDiscoverable)
    }

    private var selectedTag: Tag? {
        festivalData.tags.first { $0.id == tagID }
    }

    private var eventCounts: [String: Int] {
        var counts = [String: Int]()
        for event in festivalData.events {
            let tags = event.tags
            for id in Set(tags.map(\.id)) {
                counts[id, default: 0] += 1
            }
        }
        return counts
    }

    private var events: [Event] {
        guard let tagID else { return [] }
        return festivalData.events.filter { event in
            event.tags.contains { $0.id == tagID }
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
    let editorialContent: FestivalEditorialContent?

    @Environment(\.festivalData) private var festivalData
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var profile: FestivalProfileStore
    @State private var showsMap = false
    @State private var heroIsVisible = true

    private var stageColor: Color {
        StageNumber.baseColor(for: event.stage, colorScheme: colorScheme)
    }

    private var metadata: String {
        var values = event.tag.map { [$0.localizedName] } ?? []
        if let duration = event.confirmedDuration {
            values.append(String(format: String(localized: "program.event.duration"), Int64(duration.minutes)))
        }
        return values.joined(separator: " · ")
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    hero(topInset: geometry.safeAreaInsets.top)
                    VStack(alignment: .leading, spacing: 28) {
                        if case .unavailable = festivalData.features.eventDetails {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("program.event.additional").font(.title3.bold())
                                Text("program.event.details.unavailable")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let editorialContent, editorialContent.hasContent {
                            ProgramEventEditorialContent(content: editorialContent)
                        }
                        if event.stage.hasLocation {
                            location
                        }
                    }
                    .frame(maxWidth: 680, alignment: .leading)
                    .padding(20)
                    .frame(maxWidth: .infinity)
                }
            }
            #if os(iOS)
                .ignoresSafeArea(.container, edges: .top)
                .modifier(DetailTopScrollEdgeEffect(isHidden: heroIsVisible))
            #endif
        }
        .navigationTitle(heroIsVisible ? "" : String(localized: "program.event.title"))
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(heroIsVisible ? .hidden : .automatic, for: .navigationBar)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if profile.userDataPolicy.savedEvents == .editable {
                    Button {
                        profile.toggleSavedEvent(event)
                    } label: {
                        savedEventSymbol
                    }
                    .buttonBorderShape(.circle)
                    .accessibilityLabel(Text(isSaved ? "event.saved.remove" : "event.saved.add"))
                    .accessibilityValue(Text(isSaved ? "event.saved.value.saved" : "event.saved.value.not_saved"))
                    .accessibilityAddTraits(isSaved ? .isSelected : [])
                    .accessibilityIdentifier("concert-toggle-saved")
                } else if isSaved {
                    Image(systemName: "bookmark.fill")
                        .accessibilityLabel(Text("event.saved.value.saved"))
                }
            }
        }
        #if os(iOS)
            .sheet(isPresented: $showsMap) {
                StageDetailInteractiveMap(stage: event.stage)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        #endif
        .accessibilityIdentifier("concert-detail-\(event.id)")
    }

    private var isSaved: Bool {
        profile.isEventSaved(event.id)
    }

    @ViewBuilder
    private var savedEventSymbol: some View {
        let symbol = Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
        if #available(iOS 17.0, macOS 14.0, *) {
            symbol
                .contentTransition(.symbolEffect(.replace))
                .animation(.default, value: isSaved)
        } else {
            symbol
        }
    }

    private func hero(topInset: CGFloat) -> some View {
        VStack(spacing: 8) {
            EventTimeBadge(event: event, size: 64, headerColor: stageColor)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            Text(fullDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            NavigationLink(
                value: AppNavigationRoute.stage(id: event.stage.id, highlightedEventId: event.id)
            ) {
                HStack(spacing: 8) {
                    StageNumber(stage: event.stage, size: 30)
                        .accessibilityHidden(true)
                    Text(event.stage.localizedName)
                        .font(.title3)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!event.stage.isMetadataAvailable)
            .accessibilityIdentifier("concert-open-stage")

            NavigationLink(
                value: AppNavigationRoute.artist(
                    id: event.artist.id, highlightedEventId: event.id, transitionSourceID: nil)
            ) {
                HStack(spacing: 10) {
                    ArtistImageView(artist: event.artist, fullImage: false, loadingStyle: .quiet)
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
                        .accessibilityHidden(true)
                    Text(event.artist.formattedName)
                        .font(.title.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHeading(.h1)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!event.artist.isMetadataAvailable)
            .accessibilityIdentifier("concert-open-artist")
            .padding(.vertical, 4)

            if !metadata.isEmpty {
                Text(metadata).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 16 : 20)
        .padding(.top, topInset + 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { geometry in
                RadialGradient(
                    colors: [
                        stageColor.opacity(colorScheme == .dark ? 0.34 : 0.14),
                        stageColor.opacity(colorScheme == .dark ? 0.18 : 0.28),
                    ],
                    center: UnitPoint(x: 0.5, y: (topInset + 44) / max(geometry.size.height, 1)),
                    startRadius: 0, endRadius: geometry.size.width / 2
                )
                .background(.background)
            }
        }
        .modifier(ProgramEventHeroVisibility(isVisible: $heroIsVisible))
    }

    private var fullDate: String {
        guard let date = event.festivalDate ?? event.knownDate else {
            return String(localized: "event.date.unknown")
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = event.timeZone
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private var location: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("program.event.location").font(.title3.bold())
            #if os(iOS)
                Button {
                    showsMap = true
                } label: {
                    StageMapView(stage: event.stage)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("program.event.open_map"))
                Button("program.event.open_map") { showsMap = true }
                    .frame(minHeight: 44, alignment: .leading)
            #else
                NavigationLink(
                    value: AppNavigationRoute.stage(id: event.stage.id, highlightedEventId: event.id)
                ) {
                    Label("program.event.open_map", systemImage: "map")
                }
            #endif
        }
    }
}

private struct ProgramEventHeroVisibility: ViewModifier {
    @Binding var isVisible: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollVisibilityChange(threshold: 0.1) { isVisible = $0 }
        } else {
            content
        }
    }
}

private struct ProgramEventEditorialContent: View {
    let content: FestivalEditorialContent

    private var articleText: String {
        guard let article = content.article else { return "" }
        let text = article.text.resolved()
        return (article.format == .html ? formatString(text) : text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !articleText.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("program.event.about").font(.title3.bold())
                    Text(articleText).textSelection(.enabled)
                }
            }
            ForEach(content.fields.filter(\.hasContent)) { field in
                VStack(alignment: .leading, spacing: 6) {
                    Text(field.title.resolved()).font(.subheadline).foregroundStyle(.secondary)
                    Text(field.value.resolved()).textSelection(.enabled)
                }
                .accessibilityElement(children: .combine)
            }
            if !content.nativeLinks.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(content.nativeLinks) { link in
                        if link.openingMode == .inAppBrowser {
                            NavigationLink {
                                EmbeddedWebView(url: link.destination)
                            } label: {
                                HStack {
                                    Text(link.title.resolved())
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(minHeight: 44)
                            }
                            .foregroundStyle(.primary)
                        } else {
                            Link(link.title.resolved(), destination: link.destination)
                                .frame(minHeight: 44, alignment: .leading)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
