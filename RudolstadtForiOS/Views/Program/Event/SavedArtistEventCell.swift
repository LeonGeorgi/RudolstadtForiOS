//
//  ProgramEventItem.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct SavedArtistEventCell: View {
    let event: Event

    @EnvironmentObject var settings: UserSettings

    func artistRating() -> Int {
        return settings.ratings["\(self.event.artist.id)"] ?? 0
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
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
                    if self.settings.savedEvents.contains(self.event.id) {
                        Spacer()
                        Image(systemName: "bookmark.fill")
                                .foregroundColor(.yellow)
                    }
                    if artistRating() != 0 {
                        if !self.settings.savedEvents.contains(self.event.id) {
                            Spacer()
                        }
                        ArtistRatingSymbol(artist: self.event.artist)
                    }
                }

            }
        }.contextMenu {
            SaveEventButton(event: event)
        }

    }
}

struct SavedArtistEventCell_Previews: PreviewProvider {
    static var previews: some View {
        TimeProgramEventCell(event: .example)
    }
}
