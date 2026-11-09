#if os(iOS)
import SwiftUI
import RudolstadtCore

struct SharedFestivalProfileDetailView: View {
    let profile: SharedFestivalProfile
    var section: FriendProfileSection? = nil
    var friendUID: String? = nil

    @Environment(\.festivalData) private var festivalData
    @Environment(\.festivalEdition) private var festivalEdition
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var currentProfile: FestivalProfileStore
    @EnvironmentObject private var settings: UserSettings

    @ScaledMetric(relativeTo: .body) private var cardWidth: CGFloat = 156
    @State private var overviewWidth: CGFloat = 0

    private var artworkSize: CGFloat {
        guard overviewWidth > 40 else { return cardWidth }
        let widthFraction: CGFloat = dynamicTypeSize.isAccessibilitySize ? 0.9 : 0.47
        return min(cardWidth, (overviewWidth - 40) * widthFraction)
    }

    var body: some View {
        let content = FriendProfileContent(
            profile: profile, festivalData: festivalData, ownSavedEventIDs: currentProfile.savedEvents,
            ownRatings: currentProfile.ratings, locale: locale)
        Group {
            if let section {
                fullList(section, content: content)
            } else {
                overview(content)
            }
        }
        .navigationTitle(section.map(title(for:)) ?? profile.badge.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func overview(_ content: FriendProfileContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                profileHeader
                    .padding(.horizontal, 20)

                if content.saved.isEmpty && content.ratings.isEmpty {
                    ContentUnavailableView {
                        Label("friends.ui.no.content", systemImage: "person.crop.circle")
                    } description: {
                        Text("friends.ui.no.content.hint")
                    }
                } else {
                    if !content.shared.isEmpty {
                        preview(.shared) {
                            eventPreview(content.shared)
                        }
                    }
                    if content.hasDiscoveries {
                        preview(.discoveries) {
                            carousel {
                                ForEach(content.discoveries) { event in
                                    eventLink(event) {
                                        card(artist: event.artist) {
                                            let subtitle = [shortDay(for: event), event.timeAsString]
                                                .compactMap { $0 }.joined(separator: " · ")
                                            Text(subtitle)
                                        }
                                    }
                                }
                                ForEach(content.discoveryRatings) { rating in
                                    ratedArtistCard(rating)
                                }
                            }
                        }
                    }
                    if !content.saved.isEmpty {
                        preview(.saved) {
                            eventPreview(content.saved)
                        }
                    }
                    if !content.ratings.isEmpty {
                        preview(.ratings) {
                            carousel {
                                ForEach(content.ratings) { rating in
                                    ratedArtistCard(rating)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { overviewWidth = $0 }
        .background(Color(uiColor: .systemBackground))
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            FestivalProfileBadgeAvatar(badge: profile.badge, diameter: 52)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.badge.displayName)
                    .font(.title.bold())
                Text(verbatim: "\(festivalEdition.metadata.name.resolved(locale: locale)) \(profile.year)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func preview<Content: View>(
        _ section: FriendProfileSection, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(value: sectionRoute(section)) {
                FriendSectionLinkLabel(title: Text(title(for: section)))
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("friend-profile-\(section.rawValue)")
            .padding(.horizontal, 20)

            content()
        }
    }

    @ViewBuilder
    private func eventPreview(_ events: [Event]) -> some View {
        let rowsPerPage = 3
        let horizontalInset: CGFloat = 20

        if events.count <= rowsPerPage {
            eventPreviewPage(events[...])
                .padding(.horizontal, horizontalInset)
        } else {
            let pageStarts = Array(stride(from: 0, to: events.count, by: rowsPerPage))
            let nextPagePeek: CGFloat = dynamicTypeSize.isAccessibilitySize ? 0 : 24

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(pageStarts, id: \.self) { start in
                        let end = min(start + rowsPerPage, events.count)
                        eventPreviewPage(events[start..<end])
                            .containerRelativeFrame(.horizontal) { width, _ in
                                max(0, width - nextPagePeek)
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(.trailing, nextPagePeek)
            }
            .contentMargins(.horizontal, horizontalInset, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollIndicators(.hidden)
        }
    }

    private func eventPreviewPage(_ events: ArraySlice<Event>) -> some View {
        VStack(spacing: 0) {
            ForEach(events) { event in
                eventListRow(event, dayLabel: shortDay(for: event))
                    .padding(.vertical, 4)

                if event.id != events.last?.id {
                    Divider()
                        .padding(.leading, FestivalListRowStyle.imageWidth + FestivalListRowStyle.columnSpacing)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func eventListRow(_ event: Event, dayLabel: String? = nil) -> some View {
        HStack(spacing: 0) {
            eventLink(event) {
                SharedProfileSavedEventRow(event: event, dayLabel: dayLabel)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)

            EventSavedIcon(
                event: event,
                isSaved: currentProfile.isEventSaved(event.id),
                symbolAlignment: .trailing,
                showsEmptyWhenReadOnly: true
            ) {
                currentProfile.toggleSavedEvent(event)
            }
        }
    }

    private func carousel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 12) {
                content()
                    .buttonStyle(.plain)
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }

    private func card<Subtitle: View>(
        artist: Artist, @ViewBuilder subtitle: () -> Subtitle
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ArtistImageView(artist: artist, fullImage: true, loadingStyle: .quiet)
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(.rect(cornerRadius: 10))
                .accessibilityHidden(true)
            Text(artist.formattedName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            subtitle()
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(width: artworkSize, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private func ratedArtistCard(_ rating: FriendProfileContent.RatedArtist) -> some View {
        artistLink(rating.artist) {
            card(artist: rating.artist) {
                SharedProfileArtistRatingLabel(preference: rating.preference)
            }
        }
    }

    private func fullList(_ section: FriendProfileSection, content: FriendProfileContent) -> some View {
        List {
            if section == .ratings {
                if content.ratings.isEmpty {
                    Text("friends.detail.artist_ratings.empty").foregroundStyle(.secondary)
                }
                artistRatingRows(content.ratings)
            } else {
                let events = content.events(in: section)
                let includesRatings = section == .discoveries && !content.discoveryRatings.isEmpty
                if events.isEmpty && !includesRatings {
                    Text(emptyEventListMessage(for: section)).foregroundStyle(.secondary)
                }
                ForEach(eventGroups(events)) { group in
                    Section {
                        ForEach(group.events) { event in
                            eventListRow(event)
                                .listRowInsets(fullListRowInsets)
                        }
                    } header: {
                        if let day = group.day, let event = group.events.first {
                            Text(formatDay(day, for: event, template: "EEEE d MMMM"))
                                .textCase(nil)
                        } else {
                            Text("event.date.unknown")
                                .textCase(nil)
                        }
                    }
                }
                if includesRatings {
                    Section {
                        artistRatingRows(content.discoveryRatings)
                    } header: {
                        Text("friends.detail.artist_ratings.section").textCase(nil)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func artistRatingRows(_ ratings: [FriendProfileContent.RatedArtist]) -> some View {
        ForEach(ratings) { rating in
            artistLink(rating.artist) {
                SharedProfileRatedArtistRow(artist: rating.artist, preference: rating.preference)
            }
            .navigationLinkIndicatorVisibility(.hidden)
            .listRowInsets(fullListRowInsets)
        }
    }

    private var fullListRowInsets: EdgeInsets {
        let vertical: CGFloat = dynamicTypeSize.isAccessibilitySize ? 12 : 6
        return EdgeInsets(top: vertical, leading: 16, bottom: vertical, trailing: 16)
    }

    private func emptyEventListMessage(for section: FriendProfileSection) -> LocalizedStringKey {
        switch section {
        case .shared: "friends.detail.shared.empty"
        case .discoveries: "friends.detail.discoveries.empty"
        case .saved, .ratings: "friends.detail.saved_events.empty"
        }
    }

    private func eventLink<Label: View>(_ event: Event, @ViewBuilder label: () -> Label) -> some View {
        NavigationLink(
            value: festivalData.eventDestination(event, alwaysShowDetails: settings.alwaysShowEventDetails),
            label: label)
    }

    private func artistLink<Label: View>(_ artist: Artist, @ViewBuilder label: () -> Label) -> some View {
        NavigationLink(
            value: AppNavigationRoute.artist(id: artist.id, highlightedEventId: nil, transitionSourceID: nil),
            label: label)
    }

    private func sectionRoute(_ section: FriendProfileSection) -> AppNavigationRoute {
        if let friendUID { return .firebaseFriend(uid: friendUID, section: section) }
        return .sharedFestivalProfile(profile: profile, section: section)
    }

    private func title(for section: FriendProfileSection) -> String {
        let key: String
        switch section {
        case .shared: return friendsLocalizedString("friends.detail.shared")
        case .discoveries: key = "friends.detail.discoveries"
        case .saved: key = "friends.detail.saved_by"
        case .ratings: key = "friends.detail.ratings_by"
        }
        return String.localizedStringWithFormat(friendsLocalizedString(key), profile.badge.displayName)
    }

    private func shortDay(for event: Event) -> String? {
        eventDay(event).map { formatDay($0, for: event, template: "EEE") }
    }

    private func eventGroups(_ events: [Event]) -> [SavedEventDayGroup] {
        Dictionary(grouping: events, by: eventDay)
            .map { SavedEventDayGroup(day: $0.key, events: $0.value) }
            .sorted { ($0.day ?? .distantFuture) < ($1.day ?? .distantFuture) }
    }

    private func eventDay(_ event: Event) -> Date? {
        (event.programDay?.interval.start ?? event.knownDate ?? event.startDate)
            .map { event.calendar.startOfDay(for: $0) }
    }

    private func formatDay(_ day: Date, for event: Event, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = event.calendar
        formatter.timeZone = event.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: day)
    }
}

private struct SavedEventDayGroup: Identifiable {
    let day: Date?
    let events: [Event]
    var id: Date? { day }
}

struct FriendProfileContent {
    struct RatedArtist: Identifiable {
        let artist: Artist
        let preference: FestivalArtistPreference
        var id: Int { artist.id }
    }

    let saved: [Event]
    let shared: [Event]
    let discoveries: [Event]
    let ratings: [RatedArtist]
    let discoveryRatings: [RatedArtist]

    var hasDiscoveries: Bool { !discoveries.isEmpty || !discoveryRatings.isEmpty }

    init(
        profile: SharedFestivalProfile, festivalData: FestivalData, ownSavedEventIDs: [Int],
        ownRatings: [String: Int] = [:], locale: Locale = .current
    ) {
        let ownSaved = Set(ownSavedEventIDs)
        let matchesEdition = Int(profile.year) == festivalData.festivalYear
        let savedIDs = matchesEdition ? Set(profile.saved.map(\.intValue)) : []
        let preferences = matchesEdition ? Dictionary(
            profile.preferences.map { (Int($0.artistID), $0.native) },
            uniquingKeysWith: { _, latest in latest }) : [:]
        let saved = festivalData.events.filter { savedIDs.contains($0.id) }.sorted(by: Event.precedes)
        self.saved = saved
        shared = saved.filter { ownSaved.contains($0.id) }
        let discoveries = saved.filter { !ownSaved.contains($0.id) }
        self.discoveries = discoveries
        let ratings: [RatedArtist] = festivalData.artists.compactMap { artist in
            guard let preference = preferences[artist.id], preference.rating != 0 else { return nil }
            return RatedArtist(artist: artist, preference: preference)
        }
        .sorted { $0.artist.formattedName.localizedCaseInsensitiveCompare($1.artist.formattedName) == .orderedAscending }
        self.ratings = ratings

        let artistsWithDiscoveryEvents = Set(discoveries.map(\.artistID))
        let candidates = ratings.map(\.artist).filter { !artistsWithDiscoveryEvents.contains($0.id) }
        if candidates.isEmpty {
            discoveryRatings = []
        } else {
            discoveryRatings = FriendRecommendationContext(
                artists: candidates, events: festivalData.events, locale: locale
            )
            .recommendations(friendProfiles: [profile], savedEventIDs: ownSavedEventIDs, ratings: ownRatings)
            .compactMap { recommendation in
                guard case .rating(let preference)? = recommendation.contributions.first?.kind else { return nil }
                return RatedArtist(artist: recommendation.artist, preference: preference)
            }
        }
    }

    func events(in section: FriendProfileSection) -> [Event] {
        switch section {
        case .shared: shared
        case .discoveries: discoveries
        case .saved: saved
        case .ratings: []
        }
    }
}
#endif
