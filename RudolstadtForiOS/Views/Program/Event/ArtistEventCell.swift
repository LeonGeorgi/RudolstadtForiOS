//
//  ArtistConcertItem.swift
//  RudolstadtForiOS
//
//  Created by Leon on 25.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ArtistEventCell: View {
    let event: Event

    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var dataStore: DataStore

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
        VStack(alignment: .leading, spacing: 2) {
            if event.tag != nil {
                Text(event.tag!.localizedName.uppercased())
                        .font(.caption)
                        //.padding(.vertical, 2)
                        //.padding(.horizontal, 6)
                        .foregroundColor(.accentColor)
                        //.background(Color.accentColor)
                        //.foregroundColor(.white)
                        //.cornerRadius(100)
                        .lineLimit(1)
            }
            HStack(alignment: .bottom) {
                Text("\(event.shortWeekDay) \(event.timeAsString)")
                        .padding(.trailing, 10)
                        .lineLimit(1)
                //.frame(width: 80, alignment: .leading)
                Text(event.stage.localizedName).lineLimit(1)
            }
            ForEach(eventsThatIntersect()) { (intersectingEvent: Event) in
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    Text("gleichzeitig mit \"\(intersectingEvent.artist.name)\"") // TODO
                            .font(.caption)
                            .foregroundColor(.orange)
                }
            }
        }.contextMenu {
            Button(action: {
                if !self.settings.savedEvents.contains(self.event.id) {
                    self.settings.savedEvents.append(self.event.id)
                } else {
                    self.settings.savedEvents.remove(at: self.settings.savedEvents.firstIndex(of: self.event.id)!)
                }
            }) {
                if self.settings.savedEvents.contains(self.event.id) {
                    Text("event.remove")
                    Image(systemName: "bookmark.fill")
                } else {
                    Text("event.save")
                    Image(systemName: "bookmark")
                            .font(.body)
                }
            }
        }
    }
}

struct ArtistEventCell_Previews: PreviewProvider {
    static var previews: some View {
        ArtistEventCell(event: .example)
    }
}
