//
//  ArtistListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI
import URLImage

struct ArtistListView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingSheet = false
    @State var filterArtistTypes = Set(ArtistType.allCases)

    @State var seachText = ""

    func selectedArtists() -> [Artist] {
        return dataStore.artists.filter { artist in
            filterArtistTypes.contains(artist.artistType)
        }
    }

    var body: some View {
        List {
            /*SearchBar(text: $seachText)
                    .listRowInsets(EdgeInsets())*/
            ForEach(selectedArtists()) { (artist: Artist) in
                NavigationLink(destination: ArtistDetailView(artist: artist)) {
                    ArtistCell(artist: artist)
                }

            }
        }.gesture(DragGesture().onChanged { _ in
                    UIApplication.shared.endEditing(true)
                })
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
