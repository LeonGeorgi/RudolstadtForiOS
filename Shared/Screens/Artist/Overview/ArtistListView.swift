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
    @EnvironmentObject var dataStore: DataStore
    @State private var showingSheet = false
    @State var filterArtistTypes = Set(ArtistType.allCases)

    @State var searchText = ""

    func normalize(string: String) -> String {
        string.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale.current)
    }

    func getFilteredArtists() -> [Artist] {
        dataStore.artists.filter { artist in
            filterArtistTypes.contains(artist.artistType)
        }
    }

    var body: some View {
        List {
            ForEach(getFilteredArtists().withApplied(searchTerm: searchText) { artist in
                artist.name
            }) { (artist: Artist) in
                NavigationLink(destination: ArtistDetailView(artist: artist)) {
                    ArtistCell(artist: artist)
                }

            }
        }
                .searchable(text: $searchText)
                .navigationBarTitle("artists.title")
                .navigationBarItems(trailing: Button(action: {
                    self.showingSheet = true
                }) {
                    Text("filter.button")
                })
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

struct ArtistListView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistListView()
                .environmentObject(DataStore())
    }
}
