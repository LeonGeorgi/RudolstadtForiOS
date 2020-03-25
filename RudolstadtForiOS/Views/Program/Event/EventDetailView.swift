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

    var savedEventIds: [Int] {
        settings.savedEvents
    }

    func eventsThatIntersect() -> [Event] {
        let savedEvents = dataStore.events.filter {
            savedEventIds.contains($0.id)
        }
        return savedEvents.filter {
            $0.artist.id != event.artist.id && $0.intersects(with: event)
        }
    }

    var body: some View {
        List {

            NavigationLink(destination: ArtistDetailView(artist: event.artist)) {
                HStack(spacing: 12) {
                    ArtistImageView(artist: event.artist, fullImage: false)
                            .frame(width: 75, height: 75)
                            .cornerRadius(.infinity)
                    Text(event.artist.name)
                            .font(.system(size: 22))
                            .fontWeight(.bold)
                            .padding(.trailing, 12)
                    if (savedEventIds.contains(event.id)) {
                        Spacer()
                        Image(systemName: "bookmark.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 22))
                    }
                }
            }

            NavigationLink(destination: StageDetailView(stage: event.stage)) {
                Text(event.stage.localizedName)
            }
            if event.tag != nil {
                Text(event.tag!.localizedName)
                        .font(.system(size: 15, design: .rounded))
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(.infinity)
                        .lineLimit(1)
            }
            ForEach(eventsThatIntersect()) { (intersectingEvent: Event) in
                NavigationLink(destination: EventDetailView(event: intersectingEvent)) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.orange)
                        Text("gleichzeitig mit \"\(intersectingEvent.artist.name)\"") // TODO
                                .lineLimit(2)
                                .foregroundColor(.orange)
                    }
                }
            }

            Section(header: Text("event.map")) {
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
                        Text("event.remove")
                    } else {
                        Text("event.save")
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
