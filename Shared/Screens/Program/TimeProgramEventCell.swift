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
    let contextPreviewState: EventContextPreviewState
    let onToggleSaved: () -> Void

    private var isSaved: Bool {
        contextPreviewState.isSaved
    }

    private var artistRating: Int {
        contextPreviewState.artistRating
    }

    private var artistIconName: String? {
        contextPreviewState.artistIconName
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
                                .foregroundColor(.secondary)
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

                    if artistRating != 0 {
                        ArtistRatingSymbol(rating: artistRating, iconName: artistIconName)
                            .foregroundStyle(.secondary)
                    }
                    EventSavedIcon(event: self.event, isSaved: isSaved, onToggle: onToggleSaved)

                }

            }
        }.contextMenu {
            SaveEventButton(event: event, isSaved: isSaved, onToggle: onToggleSaved)
        } preview: {
            EventContextPreview(
                event: event,
                state: contextPreviewState
            )
        }

    }
}

struct TimeProgramEventCell_Previews: PreviewProvider {
    static var previews: some View {
        TimeProgramEventCell(
            event: .example,
            contextPreviewState: EventContextPreviewState(
                isSaved: false,
                artistRating: 0,
                artistIconName: nil,
                friendProfilesWhoSavedEvent: [],
                artistNote: nil,
                isArtistSummaryEnabled: true
            ),
            onToggleSaved: {}
        )
    }
}
