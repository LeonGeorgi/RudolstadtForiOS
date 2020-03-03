//
//  ArtistListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI
import URLImage

struct MarkedArtistListView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var settings: UserSettings

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
        List {
            ForEach(artists()) { (artist: Artist) in
                NavigationLink(destination: ArtistDetailView(artist: artist)) {
                    ArtistCell(artist: artist)
                }

            }
        }.navigationBarTitle("Marked")
    }
}

struct MarkedArtistListView_Previews: PreviewProvider {
    static var previews: some View {
        MarkedArtistListView()
                .environmentObject(DataStore())
    }
}
