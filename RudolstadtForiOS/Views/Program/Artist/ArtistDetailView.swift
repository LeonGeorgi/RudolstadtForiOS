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

    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var dataStore: DataStore

    var artistEvents: [Event] {
        return dataStore.events.filter {
            $0.artist.id == artist.id
        }
    }

    func rateArtist(rating: Int) {
        print(settings.ratings)
        var ratings = settings.ratings
        ratings["\(self.artist.id)"] = rating
        print(ratings)
        settings.ratings = ratings

    }

    func artistRating() -> Int {
        return settings.ratings["\(self.artist.id)"] ?? 0
    }

    var body: some View {
        List {
            Section(footer: Text(artist.name)) {
                ArtistImageView(artist: artist, fullImage: true).listRowInsets(EdgeInsets())
            }

            Section {
                HStack {
                    Spacer()
                    ForEach(0..<5) { index in
                        Image(systemName: "star.fill")
                                .font(.system(size: 30))
                                .foregroundColor(self.artistRating() >= index + 1 ? .accentColor : .secondary)
                                .onTapGesture {
                                    if self.artistRating() != index + 1 {
                                        self.rateArtist(rating: index + 1)
                                    } else {
                                        self.rateArtist(rating: 0)
                                    }
                                }

                    }
                    Spacer()
                }.padding(.vertical)
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
    }
}

struct ArtistDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistDetailView(artist: .example)
    }
}
