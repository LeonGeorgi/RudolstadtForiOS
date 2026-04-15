//
//  ScheduleView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct RecommendationScheduleView: View {
    
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var settings: UserSettings
    
    @State private var selectedDay = -1
    
    var storedEvents: [Int] {
        settings.savedEvents
    }
    
    var interestingArtists: [Int] {
        settings.ratings.filter { element in
            element.value > 0
        }.keys.map { a in Int(a)! }
    }
    
    private var availableEventDays: [Int] {
        guard case .success(let entities) = dataStore.data else {
            return []
        }
        
        return festivalDays(from: entities.events)
    }
    
    private var currentDayLabel: String {
        if availableEventDays.contains(selectedDay) {
            return Util.shortWeekDay(day: selectedDay)
        }
        
        if let firstDay = availableEventDays.first {
            return Util.shortWeekDay(day: firstDay)
        }
        
        return "--"
    }
    
    private var canGoToPreviousDay: Bool {
        guard let index = availableEventDays.firstIndex(of: selectedDay) else {
            return false
        }
        
        return index > 0
    }
    
    private var canGoToNextDay: Bool {
        guard let index = availableEventDays.firstIndex(of: selectedDay) else {
            return false
        }
        
        return index < availableEventDays.count - 1
    }
    
    func generateShownEvents(events: [Event]) -> [Event]? {
        switch settings.getScheduleFilterType(settings.scheduleFilterType) {
        case .saved:
            return events.filter { event in
                storedEvents.contains(event.id)
            }
        case .optimal:
            if let recommendations = dataStore.recommendedEvents {
                return events.filter { event in
                    storedEvents.contains(event.id)
                    || recommendations.contains(event.id)
                }
            } else {
                return []
            }
        case .interesting:
            return events.filter { event in
                storedEvents.contains(event.id)
                || interestingArtists.contains(event.artist.id)
            }
        case .all:
            return events
        }
    }

    var body: some View {
        Group {
            switch dataStore.data {
            case .loading:
                Text("events.loading")
            case .failure(let reason):
                Text("Failed to load: " + reason.rawValue)
            case .success(let entities):
                let shownEvents = generateShownEvents(events: entities.events)
                
                if let events = shownEvents {
                    RecommendationScheduleContentView(
                        events: events,
                        viewAsTable: settings.scheduleViewType == 0,
                        selectedDay: $selectedDay
                    )
                } else {
                    Text("recommendations.loading")
                }
            }
        }
        .onAppear {
            ensureSelectedDay()
        }
        .onChange(of: availableEventDays) { _, _ in
            ensureSelectedDay()
        }
        .navigationTitle("schedule.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !availableEventDays.isEmpty {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        moveDay(by: -1)
                    } label: {
                        Label(
                            "schedule.day.prev.button",
                            systemImage: "chevron.left"
                        )
                    }
                    .disabled(!canGoToPreviousDay)
                    
                    Menu {
                        Picker("schedule.day.picker", selection: $selectedDay) {
                            ForEach(availableEventDays, id: \.self) { day in
                                Text(Util.fullWeekDay(day: day))
                                    .tag(day)
                            }
                        }
                    } label: {
                        Text(currentDayLabel)
                            .lineLimit(1)
                            .frame(minWidth: 30)
                    }
                    
                    Button {
                        moveDay(by: 1)
                    } label: {
                        Label(
                            "schedule.day.next.button",
                            systemImage: "chevron.right"
                        )
                    }
                    .disabled(!canGoToNextDay)
                    
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    settings.toggleScheduleViewType()
                } label: {
                    if settings.scheduleViewType == 0 {
                        Label(
                            "schedule.list.button",
                            systemImage: "list.bullet"
                        )
                    } else {
                        Label(
                            "schedule.table.button",
                            systemImage: "square.grid.2x2"
                        )
                    }
                }
                .labelStyle(.iconOnly)
                
                Menu {
                    Picker(
                        "filter.button",
                        selection: Binding<ScheduleType>(
                            get: {
                                settings.getScheduleFilterType(
                                    settings.scheduleFilterType
                                )
                            },
                            set: { (type: ScheduleType) in
                                settings.setScheduleFilterType(
                                    type: type
                                )
                            }
                        )
                    ) {
                        Text("schedule.type.saved")
                            .tag(ScheduleType.saved)
                        Text("schedule.type.optimal")
                            .tag(ScheduleType.optimal)
                        Text("schedule.type.interesting")
                            .tag(ScheduleType.interesting)
                        Text("schedule.type.all")
                            .tag(ScheduleType.all)
                    }
                } label: {
                    Label(
                        "filter.button",
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                }
                .labelStyle(.iconOnly)
            }
        }
    }
    
    private func moveDay(by delta: Int) {
        guard let index = availableEventDays.firstIndex(of: selectedDay) else {
            return
        }
        
        let nextIndex = index + delta
        guard availableEventDays.indices.contains(nextIndex) else {
            return
        }
        
        selectedDay = availableEventDays[nextIndex]
    }
    
    private func ensureSelectedDay() {
        guard !availableEventDays.isEmpty else {
            selectedDay = -1
            return
        }
        
        if !availableEventDays.contains(selectedDay) {
            selectedDay =
            Util.getCurrentFestivalDay(eventDays: availableEventDays)
            ?? availableEventDays.first ?? -1
        }
    }
    
    private func festivalDays(from events: [Event]) -> [Int] {
        Set(
            events.lazy.map { (event: Event) in
                event.festivalDay
            }
        ).sorted(by: <).filter { day in
            if DataStore.year == 2023 && day < 6 {
                return false
            } else {
                return true
            }
        }
    }
}

enum ScheduleType {
    case saved, optimal, interesting, all
}

private extension View {
    @ViewBuilder
    func scheduleDaySwitcherStyle() -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular, in: .capsule)
        } else {
            self
                .background(
                    .regularMaterial,
                    in: Capsule(style: .continuous)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
        }
    }
}

struct RecommendationScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        RecommendationScheduleView()
            .environmentObject(DataStore())
    }
}
