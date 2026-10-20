//
//  ScheduleContentView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ScheduleContentView: View {

    @State private var isShowingUnplacedEvents = false
    @State private var unplacedNavigationPath = [AppNavigationRoute]()

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let events: [Event]
    let displayMode: ScheduleDisplayMode
    @Binding var selectedDay: Int
    let currentTipID: String?

    private var sections: ScheduleEventSections {
        ScheduleEventSections(events: events, selectedDay: selectedDay)
    }

    private var effectiveDisplayMode: ScheduleDisplayMode {
        dynamicTypeSize.isAccessibilitySize ? .list : displayMode
    }

    var body: some View {
        VStack(spacing: 0) {
            AppInlineTipView(
                tip: DiscoverabilityTips.eventQuickActions,
                currentTipID: currentTipID,
                arrowEdge: .bottom
            )
            .padding(.top, 8)

            if !sections.unplaced.isEmpty {
                Button {
                    unplacedNavigationPath.removeAll()
                    isShowingUnplacedEvents = true
                } label: {
                    HStack {
                        Label("event.time.unplaced", systemImage: "calendar.badge.questionmark")
                        Spacer()
                        Text(String(sections.unplaced.count)).monospacedDigit()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                }
                .accessibilityIdentifier("schedule-unplaced-events")
            }

            ZStack {
                Color(.systemBackground)

                Group {
                    if effectiveDisplayMode == .timeline {
                        ScheduleTimelineView(events: sections.scheduled)
                    } else {
                        ScheduleListView(events: sections.scheduled)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $isShowingUnplacedEvents) {
            NavigationStack(path: $unplacedNavigationPath) {
                ScheduleListView(events: sections.unplaced)
                    .navigationTitle("event.time.unplaced")
                    .navigationDestination(for: AppNavigationRoute.self) { route in
                        AppNavigationDestination(
                            route: route, navigate: { unplacedNavigationPath.append($0) })
                    }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("common.done") { isShowingUnplacedEvents = false }
                        }
                    }
            }
        }
    }
}

struct ScheduleContentView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleScreen()
            .environmentObject(DataStore())
    }
}
