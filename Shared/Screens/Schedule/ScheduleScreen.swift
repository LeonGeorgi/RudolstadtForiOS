import SwiftUI

struct ScheduleScreen: View {
    
    @Environment(\.festivalData) private var festivalData
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var profile: FestivalProfileStore
    
    @State private var selectedDay = -1
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.scheduleScreen
    )

    private var presenter: SchedulePresenter {
        SchedulePresenter(
            festivalData: festivalData,
            recommendationState: dataStore.recommendedEventIDs,
            scheduleFilterType: settings.getScheduleFilterType(
                settings.scheduleFilterType
            ),
            savedEventIds: Set(profile.savedEvents),
            positiveRatedArtistIds: Set(
                profile.ratings.compactMap { entry in
                    guard entry.value > 0 else {
                        return nil
                    }
                    return Int(entry.key)
                }
            )
        )
    }
    
    private var hasActiveFilter: Bool {
        settings.getScheduleFilterType(settings.scheduleFilterType) != .all
    }

    private var effectiveDisplayMode: ScheduleDisplayMode {
        dynamicTypeSize.isAccessibilitySize ? .list : settings.scheduleDisplayMode
    }

    var body: some View {
        Group {
            switch presenter.shownEvents {
            case .loading:
                if settings.getScheduleFilterType(settings.scheduleFilterType) == .optimal {
                    Text("recommendations.loading")
                } else {
                    Text("events.loading")
                }
            case .failure(let reason):
                Text("Failed to load: " + reason.rawValue)
            case .success(let events):
                ScheduleContentView(
                    events: events,
                    displayMode: settings.scheduleDisplayMode,
                    selectedDay: $selectedDay,
                    currentTipID: tipSequencer.currentTipID
                )
            }
        }
        .accessibilityIdentifier("schedule-screen")
        .onAppear {
            ensureSelectedDay()
        }
        .onChange(of: presenter.availableEventDays, initial: false) { _, _ in
            ensureSelectedDay()
        }
        .navigationTitle("schedule.title")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) {
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
                    .padding(.vertical, 4)
                }
                .background {
                    if effectiveDisplayMode == .timeline {
                        Color(.systemBackground)
                    }
                }
            }
        }
        .toolbar {
            if !dynamicTypeSize.isAccessibilitySize {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        settings.toggleScheduleDisplayMode()
                    } label: {
                        if settings.scheduleDisplayMode == .timeline {
                            Label(
                                "schedule.list.button",
                                systemImage: "list.bullet"
                            )
                        } else {
                            Label(
                                "schedule.timeline.button",
                                systemImage: "calendar.day.timeline.left"
                            )
                        }
                    }
                    .labelStyle(.iconOnly)
                    .appPopoverTip(
                        DiscoverabilityTips.scheduleViewMode,
                        currentTipID: tipSequencer.currentTipID,
                        arrowEdge: .top
                    )
                }

                if #available(iOS 26.0, macOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
            }
            
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker(
                        "filter.button",
                        selection: Binding<ScheduleFilter>(
                            get: {
                                settings.getScheduleFilterType(
                                    settings.scheduleFilterType
                                )
                            },
                            set: { (type: ScheduleFilter) in
                                settings.setScheduleFilterType(
                                    type: type
                                )
                            }
                        )
                    ) {
                        Text("schedule.type.saved")
                            .tag(ScheduleFilter.saved)
                        Text("schedule.type.optimal")
                            .tag(ScheduleFilter.optimal)
                        Text("schedule.type.interesting")
                            .tag(ScheduleFilter.interesting)
                        Text("schedule.type.all")
                            .tag(ScheduleFilter.all)
                    }
                } label: {
                    FilterToolbarIcon(isActive: hasActiveFilter)
                }
                .accessibilityLabel(Text("filter.button"))
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

enum ScheduleFilter: Equatable {
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

#if DEBUG
struct ScheduleScreen_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        NavigationStack {
            ScheduleScreen()
                .navigationDestination(for: AppNavigationRoute.self) { _ in
                    EmptyView()
                }
        }
        .previewMockEnvironment(suiteName: "ScheduleScreenPreview")
    }
}
#endif
