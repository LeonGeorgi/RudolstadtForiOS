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
    
    @State var showingRatingExplanation: Bool = false

    var artistEvents: LoadingEntity<[Event]> {
        dataStore.data.map { entities in
            entities.events.filter {
                $0.artist.id == artist.id
            }
        }
    }

    func rateArtist(rating: Int) {
        print(settings.ratings)
        var ratings = settings.ratings
        ratings["\(artist.id)"] = rating
        print(ratings)
        settings.ratings = ratings

    }

    func artistRating() -> Int {
        settings.ratings["\(artist.id)"] ?? 0
    }

    var body: some View {
        List {
            Section(footer: Text(artist.name)) {
                ArtistImageView(artist: artist, fullImage: true).listRowInsets(EdgeInsets())
            }

            Section(footer: VStack(alignment: .leading) {
                Text("artist.rating.explanation.content")
                if showingRatingExplanation {
                    Text("artist.rating.explanation.extra")
                }
            }) {
                HStack {
                    Spacer()
                    ForEach(0..<4) { index in
                        RatingSymbol(rating: index)
                                .font(.system(size: 35))
                                //.grayscale(1.0)
                                .saturation(artistRating() == index ? 1.0 : 0.0)
                                .onTapGesture {
                                    if artistRating() != index {
                                        self.rateArtist(rating: index)
                                    }
                                }

                    }
                    Spacer()
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                        .onTapGesture {
                            showingRatingExplanation.toggle()
                        }
                    
                }//.padding(.vertical)
            }
            //.cornerRadius(10)
            //.shadow(radius: 10)
            //.padding()
            switch artistEvents {
            case .loading:
                Text("events.loading") // TODO: translate
            case .failure(let reason):
                Text("Failed to load: " + reason.rawValue)
            case .success(let events):
                if !events.isEmpty {
                    Section(header: Text("artist.events")) {
                        ForEach(events) { (event: Event) in
                            NavigationLink(destination: StageDetailView(stage: event.stage)) {
                                ArtistEventCell(event: event)
                            }
                        }
                    }
                }
            }

            if artist.url != nil || artist.youtubeID != nil || artist.facebookID != nil {
                Section(header: Text("artist.links")) {
                    if artist.url != nil {
                        Button(action: {
                            guard let url = URL(string: artist.url!) else {
                                return
                            }
                            UIApplication.shared.open(url)
                        }) {
                            Text("artist.website")
                        }
                    }
                    if artist.youtubeID != nil {
                        Button(action: {
                            guard let url = URL(string: "https://www.youtube.com/watch?v=\(artist.youtubeID!)") else {
                                return
                            }
                            UIApplication.shared.open(url)


                        }) {
                            Text("YouTube")
                        }
                    }
                    if artist.facebookID != nil {
                        Button(action: {
                            guard let url = URL(string: "fb://profile/\(artist.facebookID!)") else {
                                return
                            }
                            if UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url)
                            } else {
                                guard let url = URL(string: "https://www.facebook.com/\(artist.facebookID!)") else {
                                    return
                                }
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Facebook")
                        }
                    }
                }
            }
            if artist.formattedDescription != nil && artist.formattedDescription != "" {
                Section(header: Text("artist.description")) {

                    Text(artist.formattedDescription!)

                }
            }

        }.listStyle(GroupedListStyle())
                .navigationBarTitle(Text(artist.name), displayMode: .large)
    }
}

struct ArtistDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistDetailView(artist: .example)
                .environmentObject(DataStore())
                .environmentObject(UserSettings())
    }
}
