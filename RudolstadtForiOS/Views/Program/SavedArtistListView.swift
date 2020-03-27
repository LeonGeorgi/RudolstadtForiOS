//
//  ArtistListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI
import URLImage

struct SavedArtistListView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var settings: UserSettings

    @State private var showingArtists = true

    func artists() -> [Artist] {
        let artists = dataStore.artists.map { artist in
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
        VStack {
            if showingArtists {
                List {
                    ForEach(artists()) { (artist: Artist) in
                        NavigationLink(destination: ArtistDetailView(artist: artist)) {
                            ArtistCell(artist: artist)
                        }
                    }
                }
            } else {
                SavedArtistProgramView()
            }
        }.navigationBarTitle("rated_artists.title", displayMode: .inline)
                .navigationBarItems(trailing: Button(action: {
                    self.showingArtists.toggle()
                }) {
                    if showingArtists {
                        Text("Konzerte") // TODO
                    } else {
                        Text("Künstler") // TODO
                    }
                })
    }
}

struct SavedArtistListView_Previews: PreviewProvider {
    static var previews: some View {
        SavedArtistListView()
                .environmentObject(DataStore())
    }
}
