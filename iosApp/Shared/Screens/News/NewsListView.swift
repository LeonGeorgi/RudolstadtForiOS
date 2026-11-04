import SwiftUI

struct NewsListView: View {

    private let allowsPullToRefresh: Bool
    private let openingNotice: LocalizedStringKey?

    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var newsStore: NewsStore
    @State var refreshButtonDisabled: Bool = false
    @State private var isShowingMarkAllReadConfirmation = false
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.newsScreen
    )

    init(allowsPullToRefresh: Bool = true, openingNotice: LocalizedStringKey? = nil) {
        self.allowsPullToRefresh = allowsPullToRefresh
        self.openingNotice = openingNotice
    }

    var body: some View {
        VStack(spacing: 0) {
            if let openingNotice {
                noticeText(openingNotice)
            }
            if let notice = newsStore.notice {
                noticeText(LocalizedStringKey(notice.rawValue))
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        refreshButtonDisabled = true
                        Task {
                            await newsStore
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

    private func noticeText(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
    }

    private var unreadNewsItems: [NewsItem] {
        guard newsStore.state.phase == .ready else {
            return []
        }

        return newsStore.state.items.filter { newsItem in
            newsItem.isInCurrentLanguage
                && !settings.readNews.contains(newsItem.id)
        }
    }

    @ViewBuilder
    private var content: some View {
        if newsStore.state.phase == .ready {
            let news = newsStore.state.items
            if news.filter({ $0.isInCurrentLanguage }).isEmpty {
                Text("news.empty")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.gray)
                    .padding(.bottom)
                    .padding()
            } else {
                newsList(news)
            }
        } else if newsStore.state.phase == .loading {
            ProgressView()
        } else if newsStore.state.phase == .failed {
            Text("news.error")
        } else {
            Text("news.error")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func newsList(_ news: [NewsItem]) -> some View {
        if allowsPullToRefresh {
            newsListContent(news)
                .refreshable {
                    await newsStore.refreshNewsIfNecessary()
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
            .previewMockEnvironment(suiteName: "NewsListViewPreview")
    }
}
