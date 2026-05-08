import SwiftUI

struct NewsListView: View {

    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var dataStore: DataStore
    @State var refreshButtonDisabled: Bool = false
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.newsScreen
    )

    var body: some View {
        renderContent()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        refreshButtonDisabled = true
                        Task {
                            await dataStore
                                .updateAndLoadNewsIfNecessary()
                            refreshButtonDisabled = false
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(refreshButtonDisabled)
                    .accessibilityLabel("news.refresh.title")
                }
            }
            .navigationTitle("news.long")
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
                                    if settings.readNews.contains(
                                        newsItem.id
                                    ) {
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
