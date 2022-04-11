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
                            Text(artist.name)
                        }
                    }
                }

                if !stages.isEmpty {
                    Section(header: Text("search.locations")) {
                        ForEach(stages) { (stage: Stage) in
                            Text(stage.localizedName)
                        }
                    }
                }


                if !events.isEmpty {
                    Section(header: Text("search.events")) {
                        ForEach(events) { (event: Event) in
                            VStack {
                                Text(event.weekDay)
                                Text(event.timeAsString)
                                Text(event.artist.name)
                                Text(event.stage.localizedName)
                                if let tag = event.tag {
                                    Text(tag.localizedName)
                                }
                            }
                        }
                    }
                }
                if !news.isEmpty {
                    Section(header: Text("search.news")) {
                        ForEach(news) { (newsItem: NewsItem) in
                            VStack {
                                Text(newsItem.shortDescription)
                                Text(newsItem.formattedLongDescription)
                                Text(newsItem.dateAsString + " " + newsItem.timeAsString)
                            }
                        }
                    }
                }
            }
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
