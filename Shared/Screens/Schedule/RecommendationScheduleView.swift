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
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.scheduleScreen
    )

    private var presenter: RecommendationSchedulePresenter {
        RecommendationSchedulePresenter(
            dataState: dataStore.data,
            recommendationState: dataStore.recommendedEvents,
            scheduleFilterType: settings.getScheduleFilterType(
                settings.scheduleFilterType
            ),
            savedEventIds: Set(settings.savedEvents),
            positiveRatedArtistIds: Set(
                settings.ratings.compactMap { entry in
                    guard entry.value > 0 else {
                        return nil
                    }
                    return Int(entry.key)
                }
            )
        )
    }

    var body: some View {
        Group {
            switch presenter.shownEvents {
            case .loading:
                if settings.getScheduleFilterType(settings.scheduleFilterType) == .optimal,
                    case .success = dataStore.data
                {
                    Text("recommendations.loading")
                } else {
                    Text("events.loading")
                }
            case .failure(let reason):
                Text("Failed to load: " + reason.rawValue)
            case .success(let events):
                RecommendationScheduleContentView(
                    events: events,
                    viewAsTable: settings.scheduleViewType == 0,
                    selectedDay: $selectedDay,
                    currentTipID: tipSequencer.currentTipID
                )
            }
        }
        .onAppear {
            ensureSelectedDay()
        }
        .onChange(of: presenter.availableEventDays, initial: false) { _, _ in
            ensureSelectedDay()
        }
        .navigationTitle("schedule.title")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            if !presenter.availableEventDays.isEmpty {
                VStack(spacing: 0) {
                    Picker("schedule.day.picker", selection: $selectedDay) {
                        ForEach(presenter.availableEventDays, id: \.self) { day in
                            Text(FestivalDateUtilities.shortWeekDay(day: day))
                                .tag(day)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(8)
                    .scheduleDaySwitcherStyle()
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    .padding(.top, 5)
                }
            }
        }
        .toolbar {
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
                .appPopoverTip(
                    DiscoverabilityTips.scheduleViewMode,
                    currentTipID: tipSequencer.currentTipID,
                    arrowEdge: .top
                )
                
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
                .appPopoverTip(
                    DiscoverabilityTips.scheduleFilters,
                    currentTipID: tipSequencer.currentTipID,
                    arrowEdge: .top
                )
            }
        }
    }
    
    private func ensureSelectedDay() {
        guard !presenter.availableEventDays.isEmpty else {
            selectedDay = -1
            return
        }
        
        if !presenter.availableEventDays.contains(selectedDay) {
            selectedDay =
                FestivalDateUtilities.getCurrentFestivalDay(
                    eventDays: presenter.availableEventDays
                )
                ?? presenter.availableEventDays.first ?? -1
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
