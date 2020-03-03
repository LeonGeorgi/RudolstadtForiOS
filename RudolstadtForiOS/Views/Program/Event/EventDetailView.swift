//
//  EventDetailView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI
import MapKit

struct EventDetailView: View {
    let event: Event
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var settings: UserSettings

    var body: some View {
        List {

            NavigationLink(destination: ArtistDetailView(artist: event.artist)) {
                HStack(spacing: 10) {
                    Text(event.artist.name)
                            .font(.system(size: 22))
                            .fontWeight(.bold)
                    Spacer()
                    ArtistImageView(artist: event.artist, fullImage: false)
                            .frame(width: 75, height: 75)
                            .cornerRadius(.infinity)
                }
            }

            NavigationLink(destination: StageDetailView(stage: event.stage)) {
                Text(event.stage.germanName)
            }
            if event.tag != nil {
                Text(event.tag!.germanName)
                        .font(.system(size: 15, design: .rounded))
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(.infinity)
                        .lineLimit(1)
            }

            Section(header: Text("MAP")) {
                Button(action: {
                    StageMapView.openInMaps(stage: self.event.stage)
                }) {
                    StageMapView(stage: event.stage)
                            .frame(minHeight: 300)
                }.listRowInsets(EdgeInsets())
            }

        }.listStyle(GroupedListStyle())
                .navigationBarTitle(Text("\(event.weekDay) \(event.timeAsString)"), displayMode: .large)
                .navigationBarItems(trailing: Button(action: {
                    let eventId = self.event.id
                    if self.settings.savedEvents.contains(eventId) {
                        if let index = self.settings.savedEvents.firstIndex(of: eventId) {
                            self.settings.savedEvents.remove(at: index)
                        }
                    } else {
                        self.settings.savedEvents.append(eventId)
                    }
                }) {
                    if self.settings.savedEvents.contains(self.event.id) {
                        Text("Remove")
                    } else {
                        Text("Save")
                    }
                })
                .listStyle(PlainListStyle())
    }
}


struct EventDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EventDetailView(event: .example)
        }
    }
}
