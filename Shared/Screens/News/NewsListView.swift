import SwiftUI

struct NewsListView: View {

    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var dataStore: DataStore
    @State var refreshButtonDisabled: Bool = false

    var body: some View {
        NavigationView {
            renderContent()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("news.refresh.title") {
                            refreshButtonDisabled = true
                            Task {
                                await dataStore
                                    .updateAndLoadNewsIfNecessary()
                                refreshButtonDisabled = false
                            }
                        }.disabled(refreshButtonDisabled)
                    }

                }.navigationTitle("news.long")
        }
    }

    @ViewBuilder
    func renderContent() -> some View {
        if case .success(let news) = dataStore.news {
            if news.isEmpty {
                VStack {
                    Spacer()
                    VStack {
                        Text("news.empty")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.bottom)
                    }
                    .padding()
                    Spacer()
                }
            } else {
                List(
                    news.filter { item in item.isInCurrentLanguage }
                ) { (newsItem: NewsItem) in
                    NewsItemCell(newsItem: newsItem)
                        .swipeActions(
                            edge: .leading,
                            allowsFullSwipe: true
                        ) {
                            Button(action: {
                                if !settings.readNews.contains(
                                    newsItem.id
                                ) {
                                    settings.readNews.append(
                                        newsItem.id
                                    )
                                } else {
                                    settings.readNews.remove(
                                        at: settings.readNews
                                            .firstIndex(
                                                of: newsItem.id
                                            )!
                                    )
                                }
                            }) {
                                if settings.readNews.contains(
                                    newsItem.id
                                ) {
                                    Image(systemName: "envelope.badge")
                                } else {
                                    Image(systemName: "envelope.open")
                                }
                            }.tint(.blue)
                        }
                }.listStyle(.plain)
                    .refreshable {
                        await dataStore.updateAndLoadNewsIfNecessary()
                    }
            }
        } else if case .loading = dataStore.news {
            VStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else if case .failure(let reason) = dataStore.news {
            VStack {
                Spacer()
                Text(reason.rawValue)
                Spacer()
            }
        } else {
            VStack {
                Spacer()
                Text("news.error")
                    .foregroundColor(.red)
                Spacer()
            }
        }
    }
}

struct NewsListView_Previews: PreviewProvider {
    static var previews: some View {
        NewsListView()
            .environmentObject(UserSettings())
    }
}
