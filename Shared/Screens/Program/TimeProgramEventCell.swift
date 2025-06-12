//
//  ProgramEventItem.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct TimeProgramEventCell: View {
    let event: Event

    @EnvironmentObject var settings: UserSettings

    func artistRating() -> Int {
        settings.ratings["\(event.artist.id)"] ?? 0
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {

                    ArtistImageView(artist: event.artist, fullImage: false)
                        .frame(width: 60, height: 52.5)
                    //.cornerRadius(4)

                    VStack(alignment: .leading) {

                        if event.tag != nil {
                            Text(event.tag!.localizedName.uppercased())
                                .font(.system(size: 11))
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                                .lineLimit(1)
                        }

                        Text(event.artist.formattedName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        Text(
                            "\(event.timeAsString) (\(event.stage.localizedName))"
                        )
                        .lineLimit(1)
                        .font(.subheadline)

                    }
                    Spacer()

                    if artistRating() != 0 {
                        ArtistRatingSymbol(artist: self.event.artist)
                    }
                    EventSavedIcon(event: self.event)

                }

            }
        }.contextMenu {
            SaveEventButton(event: event)
        }.id(settings.idFor(event: self.event))

    }
}

struct TimeProgramEventCell_Previews: PreviewProvider {
    static var previews: some View {
        TimeProgramEventCell(event: .example)
            .environmentObject(UserSettings())
    }
}
