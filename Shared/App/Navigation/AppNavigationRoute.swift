import SwiftUI

enum FriendsTogetherListKind: Hashable {
    case recommendations
}

enum AppNavigationRoute: Hashable {
    case programDiscovery(tagID: Int?)
    case artistWorldMap
    case artistCountry(code: String)
    case artist(id: Int, highlightedEventId: Int?, transitionSourceID: Int?)
    case stage(id: Int, highlightedEventId: Int?)
    case sharedFestivalProfile(profile: SharedFestivalProfile)
    case newsList
    case news(id: Int)
    case about
    case parkAndRide
    case bus
    case donation
    case settings
    case syncStatus
    case friends
    case friendsTogether(kind: FriendsTogetherListKind)
}

struct AppNavigationDestination: View {
    let route: AppNavigationRoute
    var navigate: ((AppNavigationRoute) -> Void)? = nil
    var imageTransitionNamespace: Namespace.ID? = nil

    @Environment(\.festivalData) private var festivalData

    var body: some View {
        switch route {
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
            NewsListView()
        case .news(let id):
            NewsNavigationDestination(id: id, navigate: navigate)
        case .about:
            AboutView()
        case .parkAndRide:
            ParkAndRideView()
        case .bus:
            BusView()
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
    private func artistWorldMapDestination() -> some View {
        ArtistMapScreenView(
            artists: festivalData.artists.filter { artist in
                !artist.hiddenFromArtistList
            },
            navigationTitleKey: "artists.title"
        )
    }

    @ViewBuilder
    private func artistDestination(
        id: Int,
        highlightedEventId: Int?,
        transitionSourceID: Int?
    ) -> some View {
        if let artist = festivalData.artists.first(where: { $0.id == id }) {
            let detailView = ArtistDetailView(
                artist: artist,
                highlightedEventId: highlightedEventId,
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
    private func stageDestination(id: Int, highlightedEventId: Int?) -> some View {
        if let stage = festivalData.stages.first(where: { $0.id == id }) {
            StageDetailView(stage: stage, highlightedEventId: highlightedEventId)
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
