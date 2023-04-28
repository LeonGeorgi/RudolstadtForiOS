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
    
    @State private var showingSheet = false
    @State var filterArtistTypes = Set(ArtistType.allCases)
    
    @State var searchText = ""
    @State var favoriteArtistsOnly = false
    
    let grid = true
    
    func normalize(string: String) -> String {
        string.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale.current)
    }
    
    func getFilteredArtists(data: Entities) -> [Artist] {
        data.artists.filter { artist in
            filterArtistTypes.contains(artist.artistType)
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
                getFilteredArtists(data: data).withApplied(searchTerm: searchText) { artist in
                    artist.name
                }
            }) { artists in
                List {
                    ForEach(generateArtistsToShow(artists: artists)) { (artist: Artist) in
                        NavigationLink(destination: ArtistDetailView(artist: artist)) {
                            ArtistCell(artist: artist)
                        }.listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
                    }
                }.listStyle(.plain)
            }
            .searchable(text: $searchText)
            .navigationBarTitle(favoriteArtistsOnly ? "rated_artists.title" : "artists.title")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        favoriteArtistsOnly.toggle()
                    }) {
                        if (favoriteArtistsOnly) {
                            Text("All")
                        } else {
                            Text("Favorites")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        self.showingSheet = true
                    }) {
                        Text("filter.button")
                    }
                }
            }
            .sheet(isPresented: $showingSheet) {
                NavigationView {
                    ArtistTypeFilterView(selectedArtistTypes: self.$filterArtistTypes)
                        .navigationBarItems(trailing: Button(action: { self.showingSheet = false }) {
                            Text("filter.done")
                        })
                }
            }
        }
    }
}

struct ArtistListView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistListView()
            .environmentObject(DataStore())
    }
}
