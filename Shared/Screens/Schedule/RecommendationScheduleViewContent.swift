//
//  ScheduleView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct RecommendationScheduleContentView: View {
    
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var settings: UserSettings
    
    let events: [Event]
    let viewAsTable: Bool
    
    @State private var selectedDay = -1
    
    var storedEvents: [Int] {
        settings.savedEvents
    }
    
    var interestingArtists: [Int] {
        settings.ratings.filter { element in
            element.value > 0
        }.keys.map { a in Int(a)! }
    }
    
    let eventDays: [Int]
    
    var todaysEvents: [Event] {
        events.filter { event in
            event.festivalDay == selectedDay
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack {
                Picker("Date", selection: $selectedDay) {
                    ForEach(eventDays) { (day: Int) in
                        Text(Util.shortWeekDay(day: day)).tag(day)
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 10)
                .padding(.bottom, 5)
                .pickerStyle(SegmentedPickerStyle())
            }
            .background(.ultraThinMaterial)
            .zIndex(10)
            
            if (viewAsTable) {
                ScrollableProgramView(events: todaysEvents)
            } else {
                ScheduleView(events: todaysEvents)
            }
            Spacer()
        }
        /*.horizontalSwipeGesture {
            let nextDay = selectedDay + 1
            if eventDays.contains(nextDay) {
                selectedDay = nextDay
            }
            
        } onSwipeRight: {
            let previousDay = selectedDay - 1
            if eventDays.contains(previousDay) {
                selectedDay = previousDay
            }
        }*/
        .onAppear {
            if selectedDay == -1 {
                self.selectedDay = Util.getCurrentFestivalDay(eventDays: eventDays) ?? eventDays.first ?? -1
            }
        }
    }
}

struct RecommendationScheduleContentView_Previews: PreviewProvider {
    static var previews: some View {
        RecommendationScheduleView()
            .environmentObject(DataStore())
    }
}
