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
    @State var selectedArtistTypes = Set(ArtistType.allCases)

    @State var seachText = ""

    func selectedArtists() -> [Artist] {
        return dataStore.artists.filter { artist in
            selectedArtistTypes.contains(artist.artistType)
        }
    }

    var body: some View {
        List {
            SearchBar(text: $seachText)
                    .listRowInsets(EdgeInsets())
            ForEach(selectedArtists()) { (artist: Artist) in
                NavigationLink(destination: ArtistDetailView(artist: artist)) {
                    HStack {
                        ArtistImageView(artist: artist, fullImage: false)
                                .frame(width: 80, height: 45)
                                .cornerRadius(4)
                        Text(artist.name)
                                .lineLimit(1)
                    }
                }

            }
        }.gesture(DragGesture().onChanged { _ in
                    UIApplication.shared.endEditing(true)
                })
                .navigationBarTitle("Artists")
                .navigationBarItems(trailing: Button(action: {
                    self.showingSheet = true
                }) {
                    Text("Filter")
                })
                .sheet(isPresented: $showingSheet) {
                    NavigationView {
                        ArtistTypeFilterView(selectedArtistTypes: self.$selectedArtistTypes)
                                .navigationBarItems(trailing: Button(action: { self.showingSheet = false }) {
                                    Text("Done")
                                })
                    }
                }
    }
}

struct ArtistListView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistListView()
    }
}
