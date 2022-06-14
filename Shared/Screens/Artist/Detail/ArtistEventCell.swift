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
    
    func eventsThatIntersect() -> LoadingEntity<[Event]> {
        dataStore.data.map { entities in
            let savedEvents = entities.events.filter {
                savedEventIds.contains($0.id)
            }
            return savedEvents.filter {
                $0.artist.id != event.artist.id && $0.intersects(with: event)
            }
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if event.tag != nil {
                    Text(event.tag!.localizedName.uppercased())
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                }
                HStack(alignment: .bottom) {
                    Text("\(event.shortWeekDay) \(event.timeAsString)")
                        .padding(.trailing, 10)
                        .lineLimit(1)
                    Text(event.stage.localizedName).lineLimit(1)
                }
                switch eventsThatIntersect() {
                case .loading:
                    Text("events.intersecting.loading")
                case .failure(let reason):
                    Text("Failed to load: " + reason.rawValue)
                case .success(let intersectingEvents):
                    ForEach(intersectingEvents) { (intersectingEvent: Event) in
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text(String(format: NSLocalizedString("event.intersecting.with", comment: ""), intersectingEvent.artist.name))
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
            }
            Spacer()
            EventSavedIcon(event: self.event)
        }.contextMenu {
            SaveEventButton(event: event)
        }.id(settings.idFor(event: event))
    }
}

struct ArtistEventCell_Previews: PreviewProvider {
    static var previews: some View {
        ArtistEventCell(event: .example)
    }
}
