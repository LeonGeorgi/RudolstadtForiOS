//
//  ScheduleView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct RecommendationScheduleContentView: View {

    let events: [Event]
    let viewAsTable: Bool
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
                    if viewAsTable {
                        ScrollableProgramView(events: todaysEvents)
                    } else {
                        ScheduleView(events: todaysEvents)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct RecommendationScheduleContentView_Previews: PreviewProvider {
    static var previews: some View {
        RecommendationScheduleView()
            .environmentObject(DataStore())
    }
}
