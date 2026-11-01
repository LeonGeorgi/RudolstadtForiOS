import SwiftUI

struct MoreView: View {
    @Environment(\.festivalData) private var data
    @EnvironmentObject private var dataStore: DataStore

    var body: some View {
        List {
            if dataStore.hasNews {
                NavigationLink(value: AppNavigationRoute.newsList) {
                    Label("news.long", systemImage: "megaphone.fill")
                }
            }
            ForEach(data.features.information.value?.pages ?? []) { page in
                NavigationLink(value: AppNavigationRoute.festival(.information(page.id))) {
                    Label(page.title.resolved(), systemImage: page.systemImageName ?? "info.circle")
                }
            }
            NavigationLink(value: AppNavigationRoute.about) { Label("about.title", systemImage: "info") }
            NavigationLink(value: AppNavigationRoute.donation) { Label("donations.title", systemImage: "heart") }
            NavigationLink(value: AppNavigationRoute.settings) { Label("settings.title", systemImage: "gearshape") }
            #if os(iOS)
            if dataStore.edition.usesLiveServices {
                NavigationLink(value: AppNavigationRoute.syncStatus) { Label("more.sync.title", systemImage: "icloud") }
            }
            #endif
        }
        .navigationTitle("more.title").listStyle(.plain).font(.system(size: 18))
    }
}

struct FestivalInformationView: View {
    let page: FestivalInformationPage
    @Environment(\.festivalData) private var data
    var body: some View {
        Group {
            switch page.content {
            case .webPage(let url): EmbeddedWebView(url: url)
            case .article(let content):
                List {
                    Text(content.format == .html ? formatString(content.text.resolved()) : content.text.resolved())
                    ForEach(page.relatedPlaceIDs, id: \.self) { id in
                        if let place = data.stages.first(where: { $0.id == id }) {
                            NavigationLink(value: AppNavigationRoute.stage(id: place.id, highlightedEventId: nil)) { Text(place.name.resolved()) }
                        }
                    }
                    ForEach(page.links) { link in
                        if link.openingMode == .inAppBrowser {
                            NavigationLink(link.title.resolved()) { EmbeddedWebView(url: link.destination) }
                        } else { Link(link.title.resolved(), destination: link.destination) }
                    }
                }
            }
        }.navigationTitle(page.title.resolved())
    }
}

struct FestivalNewsListView: View {
    @EnvironmentObject private var newsStore: NewsStore
    @EnvironmentObject private var settings: UserSettings
    var body: some View {
        Group {
            if newsStore.usesLegacyPresentation {
                NewsListView()
            } else if let snapshot = newsStore.snapshot {
                List(snapshot.items) { item in
                    NavigationLink(value: AppNavigationRoute.festival(.news(item.id))) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title.resolved()).font(.headline)
                            if let summary = item.summary { Text(formatString(summary.resolved())).foregroundStyle(.secondary) }
                        }
                    }
                }
            } else if case .failure = newsStore.news {
                Text("news.notification.unavailable")
            } else { ProgressView() }
        }
        .navigationTitle("news.long")
        .task { await newsStore.refreshNewsIfNecessary() }
        .refreshable { await newsStore.refreshNewsIfNecessary() }
    }
}

struct FestivalNewsDetailView: View {
    let id: String
    @EnvironmentObject private var newsStore: NewsStore
    @EnvironmentObject private var settings: UserSettings
    var body: some View {
        Group {
            if newsStore.usesLegacyPresentation, case .success(let items) = newsStore.news,
               let legacyID = Int(id), let item = items.first(where: { $0.id == legacyID && $0.isInCurrentLanguage }) {
                NewsItemDetailView(newsItem: item)
            } else if let snapshot = newsStore.snapshot, let item = snapshot.items.first(where: { $0.id == id }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(item.title.resolved()).font(.title.bold())
                        Text(item.body.format == .html ? formatString(item.body.text.resolved()) : item.body.text.resolved())
                        ForEach(item.links) { link in Link(link.title.resolved(), destination: link.destination) }
                    }.padding()
                }
                .onAppear { settings.markFestivalNewsRead(id, identity: snapshot.identity) }
            } else { Text("news.notification.unavailable") }
        }
        .task { await newsStore.refreshNewsIfNecessary() }
    }
}
