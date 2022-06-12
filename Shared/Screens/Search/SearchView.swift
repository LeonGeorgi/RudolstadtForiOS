import SwiftUI

struct SearchView: View {
    @EnvironmentObject var dataStore: DataStore

    @State(initialValue: "") var searchTerm: String

    func artists(_ entities: Entities) -> [Artist] {
        entities.artists.withApplied(searchTerm: searchTerm) { artist, term in
            artist.matches(searchTerm: term)
        }
    }

    func stages(_ entities: Entities) -> [Stage] {
        entities.stages.withApplied(searchTerm: searchTerm) { stage, term in
            stage.matches(searchTerm: term)
        }
    }

    func events(_ entities: Entities) -> [Event] {
        entities.events.withApplied(searchTerm: searchTerm) { event, term in
            event.matches(searchTerm: term)
        }
    }

    func news(_ entities: Entities) -> [NewsItem] {
        entities.news.withApplied(searchTerm: searchTerm) { newsItem, term in
            newsItem.isInCurrentLanguage && newsItem.matches(searchTerm: term)
        }
    }

    var body: some View {

        NavigationView {
            switch dataStore.data {
                case .loading:
                    Text("data.loading") // TODO: translate
                case .failure(let reason):
                    Text("Failed to load: " + reason.rawValue)
                case .success(let entities):
                    
                    List {
                        if !artists(entities).isEmpty {
                            Section(header: Text("search.artists")) {
                                ForEach(artists(entities)) { (artist: Artist) in
                                    NavigationLink(destination: ArtistDetailView(artist: artist)) {
                                        ArtistCell(artist: artist)
                                    }
                                }
                            }
                        }

                        if !stages(entities).isEmpty {
                            Section(header: Text("search.locations")) {
                                ForEach(stages(entities)) { (stage: Stage) in
                                    NavigationLink(destination: StageDetailView(stage: stage)) {
                                        StageCell(stage: stage)
                                    }
                                }
                            }
                        }


                        if !events(entities).isEmpty {
                            Section(header: Text("search.events")) {
                                ForEach(events(entities)) { (event: Event) in
                                    NavigationLink(destination: ArtistDetailView(artist: event.artist)) {
                                        SearchEventCell(event: event)
                                    }
                                }
                            }
                        }
                        if !news(entities).isEmpty {
                            Section(header: Text("search.news")) {
                                ForEach(news(entities)) { (newsItem: NewsItem) in
                                    NavigationLink(destination: NewsItemDetailView(newsItem: newsItem)) {
                                        NewsItemCell(newsItem: newsItem)
                                    }
                                }
                            }
                        }
                    }
                        .listStyle(.grouped)
                            .searchable(text: $searchTerm, placement: .navigationBarDrawer(displayMode: .always), prompt: "search.prompt")
                            .navigationBarTitle("search.title")
            }
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}
