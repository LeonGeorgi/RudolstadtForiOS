import SwiftUI

enum FriendsTogetherListKind: Hashable {
    case recommendations
}

enum AppNavigationRoute: Hashable {
    case festival(FestivalDestination)
    case programDiscovery(tagID: String?)
    case artistWorldMap
    case artistCountry(code: String)
    case artist(id: Int, highlightedEventId: Int?, transitionSourceID: Int?)
    case stage(id: FestivalPlaceID, highlightedEventId: Int?)
    case sharedFestivalProfile(profile: SharedFestivalProfile)
    case newsList
    case news(id: Int)
    case about
    case donation
    case settings
    case syncStatus
    case friends
    case friendsTogether(kind: FriendsTogetherListKind)
}

extension FestivalData {
    func eventDestination(
        _ event: Event, fallback: AppNavigationRoute? = nil, alwaysShowDetails: Bool = false
    ) -> AppNavigationRoute {
        if features.eventDetails.isSupported || alwaysShowDetails { return .festival(.event(event.id)) }
        return fallback ?? .artist(id: event.artist.id, highlightedEventId: event.id, transitionSourceID: nil)
    }
}

struct AppNavigationDestination: View {
    let route: AppNavigationRoute
    var navigate: ((AppNavigationRoute) -> Void)? = nil
    var imageTransitionNamespace: Namespace.ID? = nil

    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject private var settings: UserSettings

    var body: some View {
        switch route {
        case .festival(let destination):
            festivalDestination(destination)
        case .programDiscovery(let tagID):
            ProgramDiscoveryView(tagID: tagID)
        case .artistWorldMap:
            artistWorldMapDestination()
        case .artistCountry(let code):
            ArtistCountryListRouteView(
                countryCode: code,
                imageTransitionNamespace: imageTransitionNamespace
            )
        case .artist(let id, let highlightedEventId, let transitionSourceID):
            artistDestination(
                id: id,
                highlightedEventId: highlightedEventId,
                transitionSourceID: transitionSourceID
            )
        case .stage(let id, let highlightedEventId):
            stageDestination(id: id, highlightedEventId: highlightedEventId)
        case .sharedFestivalProfile(let profile):
            SharedFestivalProfileDetailView(profile: profile)
        case .newsList:
            FestivalNewsListView()
        case .news(let id):
            NewsNavigationDestination(id: id, navigate: navigate)
        case .about:
            AboutView()
        case .donation:
            DonationView()
        case .settings:
            SettingsView()
        case .syncStatus:
            SyncStatusView()
        case .friends:
            FriendsView()
        case .friendsTogether(let kind):
            FriendsTogetherListView(kind: kind)
        }
    }

    @ViewBuilder
    private func festivalDestination(_ destination: FestivalDestination) -> some View {
        switch destination {
        case .overview: Text("schedule.title")
        case .artist(let id, let eventID):
            let link = ArtistShareLink(year: festivalData.festivalYear, artistID: id, eventID: eventID)
            artistDestination(
                id: id, highlightedEventId: link.selectedEventID(in: festivalData.events),
                transitionSourceID: nil, scrollToHighlightedEvent: true)
        case .event(let id):
            if let event = festivalData.events.first(where: { $0.id == id }) {
                if festivalData.features.eventDetails.isSupported || settings.alwaysShowEventDetails {
                    ProgramEventDetailView(
                        event: event,
                        editorialContent: festivalData.features.eventDetails.value?.details(id: Int64(id)))
                } else {
                    artistDestination(id: event.artist.id, highlightedEventId: id, transitionSourceID: nil)
                }
            } else { Text("events.loading") }
        case .place(let id):
            stageDestination(id: id, highlightedEventId: nil)
        case .information(let id):
            if let page = festivalData.features.information.value?.page(for: id) { FestivalInformationView(page: page) }
            else { Text("site_plan.unavailable") }
        case .news(let id): FestivalNewsDetailView(id: id, navigate: navigate)
        }
    }

    @ViewBuilder
    private func artistWorldMapDestination() -> some View {
        ArtistMapScreenView(
            artists: festivalData.artists.filter { artist in
                !artist.hiddenFromArtistList
            },
            navigationTitleKey: "artists.title",
            navigate: navigate
        )
    }

    @ViewBuilder
    private func artistDestination(
        id: Int,
        highlightedEventId: Int?,
        transitionSourceID: Int?,
        scrollToHighlightedEvent: Bool = false
    ) -> some View {
        if let artist = festivalData.artists.first(where: { $0.id == id }) {
            let detailView = ArtistDetailView(
                artist: artist,
                highlightedEventId: highlightedEventId,
                scrollToHighlightedEvent: scrollToHighlightedEvent,
                navigate: navigate
            )

            if let imageTransitionNamespace, let transitionSourceID {
                detailView.artistImageNavigationTransition(
                    id: transitionSourceID,
                    namespace: imageTransitionNamespace
                )
            } else {
                detailView
            }
        } else {
            Text("artists.none-found")
        }
    }

    @ViewBuilder
    private func stageDestination(id: FestivalPlaceID, highlightedEventId: Int?) -> some View {
        if let stage = festivalData.stages.first(where: { $0.id == id }) {
            StageDetailView(stage: stage, highlightedEventId: highlightedEventId, navigate: navigate)
        } else {
            Text("locations.empty")
        }
    }
}

private struct NewsNavigationDestination: View {
    let id: Int
    let navigate: ((AppNavigationRoute) -> Void)?

    @EnvironmentObject private var newsStore: NewsStore
    @State private var hasRefreshed = false

    var body: some View {
        content.task(id: id) {
            hasRefreshed = false
            await newsStore.refreshNewsIfNecessary()
            if !Task.isCancelled { hasRefreshed = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch newsStore.notificationDestination(id: id, hasRefreshed: hasRefreshed) {
        case .item(let item):
            NewsItemDetailView(newsItem: item, navigate: navigate)
        case .loading:
            ProgressView()
        case .list:
            NewsListView(openingNotice: "news.notification.unavailable")
        }
    }
}
