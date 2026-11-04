//
//  ScheduleContentView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import RudolstadtCore
import SwiftUI

struct ScheduleContentView: View {

    @State private var isShowingUnplacedEvents = false
    @State private var unplacedNavigationPath = [AppNavigationRoute]()

    @EnvironmentObject private var profile: FestivalProfileStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let events: [Event]
    let displayMode: ScheduleDisplayMode
    @Binding var selectedDay: String?
    let currentTipID: String?
    var showsPlanTransitions = false

    private var sections: ScheduleEventSections {
        ScheduleEventSections(events: events, selectedProgramDay: selectedDay)
    }

    private var effectiveDisplayMode: ScheduleDisplayMode {
        dynamicTypeSize.isAccessibilitySize ? .list : displayMode
    }

    private var unplacedEvents: [Event] {
        effectiveDisplayMode == .timeline
            ? ProgramSchedule.shared.unplaced(events: events) : sections.unplaced
    }

    var body: some View {
        VStack(spacing: 0) {
            if !showsPlanTransitions && profile.userDataPolicy.savedEvents == .editable {
                AppInlineTipView(
                    tip: DiscoverabilityTips.eventQuickActions,
                    currentTipID: currentTipID,
                    arrowEdge: .bottom
                )
                .padding(.top, 8)
            }

            if !showsPlanTransitions && !unplacedEvents.isEmpty {
                Button {
                    unplacedNavigationPath.removeAll()
                    isShowingUnplacedEvents = true
                } label: {
                    HStack {
                        Label("event.time.unplaced", systemImage: "calendar.badge.questionmark")
                        Spacer()
                        Text(String(unplacedEvents.count)).monospacedDigit()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                }
                .accessibilityIdentifier("schedule-unplaced-events")
            }

            ZStack {
                Color(.systemBackground)

                Group {
                    if showsPlanTransitions {
                        PersonalPlanTimelineView(
                            events: sections.scheduled,
                            unknownTime: sections.unknownTime,
                            unknownDate: sections.unknownDate
                        )
                        .id(selectedDay)
                    } else if effectiveDisplayMode == .timeline {
                        ScheduleTimelineView(events: events, selectedDay: $selectedDay)
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
                ScheduleListView(events: unplacedEvents)
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
