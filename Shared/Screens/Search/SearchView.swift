import SwiftUI

struct SearchView: View {
    @EnvironmentObject var dataStore: DataStore

    @State(initialValue: "") var searchTerm: String

    var artists: [Artist] {
        dataStore.artists.withApplied(searchTerm: searchTerm) { artist, term in
            artist.matches(searchTerm: term)
        }
    }

    var stages: [Stage] {
        dataStore.stages.withApplied(searchTerm: searchTerm) { stage, term in
            stage.matches(searchTerm: term)
        }
    }

    var events: [Event] {
        dataStore.events.withApplied(searchTerm: searchTerm) { event, term in
            event.matches(searchTerm: term)
        }
    }

    var news: [NewsItem] {
        dataStore.news.withApplied(searchTerm: searchTerm) { newsItem, term in
            newsItem.isInCurrentLanguage && newsItem.matches(searchTerm: term)
        }
    }

    var body: some View {
        NavigationView {
            List {
                if !artists.isEmpty {
                    Section(header: Text("search.artists")) {
                        ForEach(artists) { (artist: Artist) in
                            NavigationLink(destination: ArtistDetailView(artist: artist)) {
                                ArtistCell(artist: artist)
                            }
                        }
                    }
                }

                if !stages.isEmpty {
                    Section(header: Text("search.locations")) {
                        ForEach(stages) { (stage: Stage) in
                            NavigationLink(destination: StageDetailView(stage: stage)) {
                                StageCell(stage: stage)
                            }
                        }
                    }
                }


                if !events.isEmpty {
                    Section(header: Text("search.events")) {
                        ForEach(events) { (event: Event) in
                            NavigationLink(destination: ArtistDetailView(artist: event.artist)) {
                                SearchEventCell(event: event)
                            }
                        }
                    }
                }
                if !news.isEmpty {
                    Section(header: Text("search.news")) {
                        ForEach(news) { (newsItem: NewsItem) in
                            NavigationLink(destination: NewsItemDetailView(newsItem: newsItem)) {
                                NewsItemCell(newsItem: newsItem)
                            }
                        }
                    }
                }
            }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchTerm, placement: .navigationBarDrawer(displayMode: .always), prompt: "search.prompt")
                    .navigationBarTitle("search.title")
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}
