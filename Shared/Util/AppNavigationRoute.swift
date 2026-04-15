import SwiftUI

enum AppNavigationRoute: Hashable {
    case artist(id: Int, highlightedEventId: Int?)
    case stage(id: Int, highlightedEventId: Int?)
    case news(id: Int)
    case about
    case parkAndRide
    case bus
    case donation
    case settings
}

struct AppNavigationDestination: View {
    let route: AppNavigationRoute

    @EnvironmentObject var dataStore: DataStore

    var body: some View {
        switch route {
        case .artist(let id, let highlightedEventId):
            artistDestination(id: id, highlightedEventId: highlightedEventId)
        case .stage(let id, let highlightedEventId):
            stageDestination(id: id, highlightedEventId: highlightedEventId)
        case .news(let id):
            newsDestination(id: id)
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
        }
    }

    @ViewBuilder
    private func artistDestination(id: Int, highlightedEventId: Int?) -> some View {
        switch dataStore.data {
        case .success(let data):
            if let artist = data.artists.first(where: { $0.id == id }) {
                ArtistDetailView(artist: artist, highlightedEventId: highlightedEventId)
            } else {
                Text("artists.none-found")
            }
        case .loading:
            ProgressView()
        case .failure(let reason):
            Text("Failed to load: " + reason.rawValue)
        }
    }

    @ViewBuilder
    private func stageDestination(id: Int, highlightedEventId: Int?) -> some View {
        switch dataStore.data {
        case .success(let data):
            if let stage = data.stages.first(where: { $0.id == id }) {
                StageDetailView(stage: stage, highlightedEventId: highlightedEventId)
            } else {
                Text("locations.empty")
            }
        case .loading:
            ProgressView()
        case .failure(let reason):
            Text("Failed to load: " + reason.rawValue)
        }
    }

    @ViewBuilder
    private func newsDestination(id: Int) -> some View {
        switch dataStore.news {
        case .success(let news):
            if let newsItem = news.first(where: { $0.id == id }) {
                NewsItemDetailView(newsItem: newsItem)
            } else {
                Text("news.empty")
            }
        case .loading:
            ProgressView()
        case .failure(let reason):
            Text(reason.rawValue)
        }
    }
}
