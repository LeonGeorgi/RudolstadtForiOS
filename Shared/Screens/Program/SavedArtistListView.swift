import SwiftUI

struct SavedArtistListView: View {

    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var settings: UserSettings

    @State(initialValue: "") var searchTerm: String

    func artists(_ entities: Entities) -> [Artist] {
        let artists = entities.artists.map { artist in
            (artist: artist, rating: settings.ratings[String(artist.id)])
        }
        let filteredArtists = artists.filter { item in
            item.rating != nil && item.rating! > 0
        }
        let sortedArtists = filteredArtists.sorted { first, second in
            first.rating! > second.rating!
        }
        return sortedArtists.map { artist, rating in
            artist
        }
    }

    var body: some View {
        LoadingListView(noDataMessage: "artists.saved.empty", dataMapper: { entities in
            artists(entities)
        }) { artistList in
            List {
                ForEach(artistList.withApplied(searchTerm: searchTerm) { artist in artist.name }) { (artist: Artist) in
                    NavigationLink(destination: ArtistDetailView(artist: artist)) {
                        ArtistCell(artist: artist)
                    }
                }
            }.listStyle(.plain)
        }
        
                .searchable(text: $searchTerm)
    }
}

struct SavedArtistListView_Previews: PreviewProvider {
    static var previews: some View {
        SavedArtistListView()
    }
}
