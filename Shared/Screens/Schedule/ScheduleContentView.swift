//
//  ScheduleContentView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ScheduleContentView: View {

    let events: [Event]
    let displayMode: ScheduleDisplayMode
    @Binding var selectedDay: Int
    let currentTipID: String?

    var todaysEvents: [Event] {
        events.filter { event in
            event.festivalDay == selectedDay
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            AppInlineTipView(
                tip: DiscoverabilityTips.eventQuickActions,
                currentTipID: currentTipID,
                arrowEdge: .bottom
            )
            .padding(.top, 8)

            ZStack {
                Color(.systemBackground)

                Group {
                    if displayMode == .timeline {
                        ScheduleTimelineView(events: todaysEvents)
                    } else {
                        ScheduleListView(events: todaysEvents)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct ScheduleContentView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleScreen()
            .environmentObject(DataStore())
    }
}
