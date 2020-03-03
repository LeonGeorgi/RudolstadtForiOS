//
//  ArtistDetailView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 25.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ArtistDetailView: View {
    let artist: Artist
    @EnvironmentObject var dataStore: DataStore

    var artistEvents: [Event] {
        return dataStore.events.filter {
            $0.artist.id == artist.id
        }
    }

    @State var rate: Bool = false
    var body: some View {
        List {
            Section(footer: Text(artist.name)) {
                ArtistImageView(artist: artist, fullImage: true).listRowInsets(EdgeInsets())
            }
            //.cornerRadius(10)
            //.shadow(radius: 10)
            //.padding()
            if !artistEvents.isEmpty {
                Section(header: Text("Events".uppercased())) {

                    ForEach(artistEvents) { (event: Event) in
                        NavigationLink(destination: EventDetailView(event: event)) {
                            ArtistEventItem(event: event)
                        }
                    }
                }
            }

            if artist.url != nil || artist.youtubeID != nil || artist.facebookID != nil {
                Section(header: Text("Links".uppercased())) {
                    if artist.url != nil {
                        Text("Website")
                    }
                    if artist.youtubeID != nil {
                        Text("Youtube")
                    }
                    if artist.facebookID != nil {
                        Text("Facebook")
                    }
                }
            }
            if artist.formattedDescription != nil && artist.formattedDescription != "" {
                Section(header: Text("Description".uppercased())) {

                    Text(artist.formattedDescription!)

                }
            }

        }.listStyle(GroupedListStyle())
                .navigationBarTitle(Text(self.artist.name), displayMode: .large)
                .navigationBarItems(trailing: Button(action: {
                    self.rate = true
                }) {
                    HStack {
                        Image(systemName: "star")
                        Text("0/5")
                    }
                })
                .actionSheet(isPresented: $rate) {
                    ActionSheet(title: Text("Rate \(artist.name)"), buttons: [
                        .default(Text("☆☆☆☆☆")),
                        .default(Text("★☆☆☆☆")),
                        .default(Text("★★☆☆☆")),
                        .default(Text("★★★☆☆")),
                        .default(Text("★★★★☆")),
                        .default(Text("★★★★★")),
                        .cancel()
                    ])
                }
    }
}

struct ArtistDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistDetailView(artist: .example)
    }
}
