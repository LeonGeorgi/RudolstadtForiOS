import SwiftUI

struct NewsListView: View {

    private let allowsPullToRefresh: Bool

    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var dataStore: DataStore
    @State var refreshButtonDisabled: Bool = false
    @State private var isShowingMarkAllReadConfirmation = false
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.newsScreen
    )

    init(allowsPullToRefresh: Bool = true) {
        self.allowsPullToRefresh = allowsPullToRefresh
    }

    var body: some View {
        renderContent()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            refreshButtonDisabled = true
                            Task {
                                await dataStore
                                    .refreshNewsIfNecessary()
                                refreshButtonDisabled = false
                            }
                        } label: {
                            Label(
                                "news.refresh.title",
                                systemImage: "arrow.clockwise"
                            )
                        }
                        .disabled(refreshButtonDisabled)
                        .accessibilityIdentifier("news-refresh")

                        Button {
                            isShowingMarkAllReadConfirmation = true
                        } label: {
                            Label(
                                "news.mark_all_read.action",
                                systemImage: "checkmark.circle"
                            )
                        }
                        .disabled(unreadNewsItems.isEmpty)
                        .accessibilityIdentifier("news-mark-all-read")
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("news.actions.title")
                    .accessibilityIdentifier("news-actions-menu")
                }
            }
            .navigationTitle("news.long")
            .confirmationDialog(
                "news.mark_all_read.title",
                isPresented: $isShowingMarkAllReadConfirmation,
                titleVisibility: .visible
            ) {
                Button("news.mark_all_read.action") {
                    settings.markNewsAsRead(unreadNewsItems)
                }
                Button("news.mark_all_read.cancel", role: .cancel) {}
            } message: {
                Text("news.mark_all_read.message")
            }
    }

    private var unreadNewsItems: [NewsItem] {
        guard case .success(let news) = dataStore.news else {
            return []
        }

        return news.filter { newsItem in
            newsItem.isInCurrentLanguage
                && !settings.readNews.contains(newsItem.id)
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
                newsList(news)
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

    @ViewBuilder
    private func newsList(_ news: [NewsItem]) -> some View {
        if allowsPullToRefresh {
            newsListContent(news)
                .refreshable {
                    await dataStore.refreshNewsIfNecessary()
                }
        } else {
            newsListContent(news)
        }
    }

    private func newsListContent(_ news: [NewsItem]) -> some View {
        List {
            AppInlineTipView(
                tip: DiscoverabilityTips.newsSwipeReadState,
                currentTipID: tipSequencer.currentTipID,
                arrowEdge: .bottom
            )
            .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowSeparator(.hidden)

            ForEach(news.filter { item in item.isInCurrentLanguage }) { newsItem in
                NewsItemCell(newsItem: newsItem)
                    .swipeActions(
                        edge: .leading,
                        allowsFullSwipe: true
                    ) {
                        Button(action: {
                            settings.toggleReadState(for: newsItem)
                        }) {
                            if settings.readNews.contains(newsItem.id) {
                                Image(systemName: "envelope.badge")
                            } else {
                                Image(systemName: "envelope.open")
                            }
                        }
                        .tint(.blue)
                    }
            }
        }
        .listStyle(.plain)
    }
}

struct NewsListView_Previews: PreviewProvider {
    static var previews: some View {
        NewsListView()
            .environmentObject(UserSettings())
    }
}
