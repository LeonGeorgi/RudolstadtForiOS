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

    var body: some View {
        ScheduleEventCell(
            event: event,
            contextPreviewState: contextPreviewState,
            onToggleSaved: onToggleSaved
        )
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
