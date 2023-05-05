//
//  ArtistListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

// import URLImage

struct ArtistListView: View {
    
    @EnvironmentObject var settings: UserSettings
    
    @State var shownArtistTypes = ShownArtistTypes.all
    
    @State var searchText = ""
    @State var favoriteArtistsOnly = false
    
    let grid = true
    
    func normalize(string: String) -> String {
        string.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale.current)
    }
    
    func getFilteredArtists(data: Entities) -> [Artist] {
        data.artists.filter { artist in
            switch shownArtistTypes {
            case .all:
                return true
            case .stage:
                return artist.artistType == .stage
            case .street:
                return artist.artistType == .street
            case .dance:
                return artist.artistType == .dance
            case .other:
                return artist.artistType == .other
            }
        }
    }
    
    func generateArtistsToShow(artists: [Artist]) -> [Artist] {
        if favoriteArtistsOnly {
            let artists = artists.map { artist in
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
        } else {
            return artists
        }
    }
    
    var body: some View {
        NavigationView {
            
            LoadingListView(noDataMessage: "artists.none-found", noDataSubtitle: nil, dataMapper: { data in
                generateArtistsToShow(artists: getFilteredArtists(data: data)).withApplied(searchTerm: searchText) { artist in
                    artist.name
                }
            }) { artists in
                List {
                    ForEach(artists) { (artist: Artist) in
                        NavigationLink(destination: ArtistDetailView(artist: artist)) {
                            ArtistCell(artist: artist)
                        }.listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
                    }
                }.listStyle(.plain)
            }
            .searchable(text: $searchText)
            .disableAutocorrection(true)
            .navigationBarTitle(favoriteArtistsOnly ? "rated_artists.title" : "artists.title")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        favoriteArtistsOnly.toggle()
                    }) {
                        if (favoriteArtistsOnly) {
                            Text("artists.all.button")
                        } else {
                            Text("artists.favorites.button")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Picker("Test", selection: $shownArtistTypes) {
                        Text("artisttypes.all")
                            .tag(ShownArtistTypes.all)
                        Text(ArtistType.stage.localizedName)
                            .tag(ShownArtistTypes.stage)
                        Text(ArtistType.street.localizedName)
                            .tag(ShownArtistTypes.street)
                        Text(ArtistType.dance.localizedName)
                            .tag(ShownArtistTypes.dance)
                        Text(ArtistType.other.localizedName)
                            .tag(ShownArtistTypes.other)
                        
                    }
                }
            }
        }
    }
}

enum ShownArtistTypes {
    case all, stage, street, dance, other;
}

struct ArtistListView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistListView()
            .environmentObject(DataStore())
    }
}
