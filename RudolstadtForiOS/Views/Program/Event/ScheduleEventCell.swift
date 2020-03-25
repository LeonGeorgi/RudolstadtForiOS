//
//  ProgramEventItem.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ScheduleEventCell: View {
    let event: Event

    @EnvironmentObject var settings: UserSettings

    @State private var showingAlert = false

    func createAlert() -> Alert {
        Alert(
                title: Text("Save \"\(event.artist.name)\" at \(event.shortWeekDay) \(event.timeAsString)?"),
                message: Text("event.save.alert.message"),
                primaryButton: .default(Text("event.save")) {
                    if !self.settings.savedEvents.contains(self.event.id) {
                        self.settings.savedEvents.append(self.event.id)
                    }
                }, secondaryButton: .cancel())
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    HStack(alignment: .center) {
                        ZStack {
                            ArtistImageView(artist: event.artist, fullImage: false)
                                    .overlay(Color.black.opacity(0.5))
                                    .frame(width: 80, height: 45)
                                    .cornerRadius(4)

                            Text(event.timeAsString)
                                    .fontWeight(.bold)
                                    .clipped()
                                    .foregroundColor(.white)
                                    .shadow(radius: 5)
                        }
                        VStack(alignment: .leading) {
                            if event.tag != nil {
                                Text(event.tag!.localizedName.uppercased())
                                        .font(.system(size: 11))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.accentColor)
                                        .lineLimit(1)
                            }
                            Text(event.artist.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                            Text(event.stage.localizedName)
                                    .lineLimit(1)
                                    .font(.footnote)

                        }
                    }.opacity(self.settings.savedEvents.contains(event.id) ? 1 : 0.6)
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

struct ScheduleEventCell_Previews: PreviewProvider {
    static var previews: some View {
        TimeProgramEventCell(event: .example)
    }
}
