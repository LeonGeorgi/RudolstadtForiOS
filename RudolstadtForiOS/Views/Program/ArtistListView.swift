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

    @State var seachText = ""

    var body: some View {
        List {
            SearchBar(text: $seachText)
                    .listRowInsets(EdgeInsets())
            ForEach(dataStore.artists) { (artist: Artist) in
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
                }).navigationBarTitle("Artists")
                .navigationBarItems(trailing: Button(action: {

                }) {
                    Text("Filter")
                })
    }
}

struct ArtistListView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistListView()
    }
}
