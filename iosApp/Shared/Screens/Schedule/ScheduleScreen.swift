import SwiftUI

struct ScheduleScreen: View {

    @Environment(\.festivalEdition) private var edition
    @Environment(\.festivalData) private var festivalData
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @EnvironmentObject var recommendations: RecommendationStore
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var profile: FestivalProfileStore

    @State private var selectedDay: String?
    @EnvironmentObject private var dataStore: DataStore
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.scheduleScreen
    )

    private var selectedFilter: ScheduleFilter {
        let filter = settings.scheduleFilter(for: dataStore.metadata.identity)
        return filter == .optimal && !dataStore.automaticPlanning.isSupported ? .all : filter
    }

    private var days: [FestivalDay] { festivalData.days }

    private var scheduleTitle: Text {
        if let day = days.first(where: { $0.id == selectedDay }) {
            Text(dayLabel(day))
        } else {
            Text("schedule.title")
        }
    }

    private var dayPicker: some View {
        Picker("schedule.day.picker", selection: $selectedDay) {
            ForEach(days) { day in
                Text(
                    settings.scheduleDaySelectionStyle == .tabs
                        ? day.label(calendar: dataStore.metadata.calendar, locale: locale)
                        : dayLabel(day)
                )
                .accessibilityLabel(dayLabel(day))
                .tag(Optional(day.id))
            }
        }
        .accessibilityIdentifier("schedule-day-picker")
    }

    private var presenter: SchedulePresenter {
        SchedulePresenter(
            festivalData: festivalData,
            recommendationState: recommendations.state,
            scheduleFilterType: selectedFilter,
            profileState: profile.state
        )
    }

    private var hasActiveFilter: Bool {
        selectedFilter != .all
    }

    var body: some View {
        Group {
            switch presenter.shownEvents {
            case .loading:
                if selectedFilter == .optimal {
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
        .safeAreaInset(edge: .top, spacing: 0) {
            if settings.scheduleDaySelectionStyle == .tabs, !days.isEmpty {
                dayPicker
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
        }
        .accessibilityIdentifier("schedule-screen")
        .onAppear {
            ensureSelectedDay()
        }
        .onChange(of: days.map(\.id), initial: false) { _, _ in
            ensureSelectedDay()
        }
        .navigationTitle(scheduleTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if settings.scheduleDaySelectionStyle == .toolbarMenu, !days.isEmpty {
                if #available(iOS 16.0, macOS 13.0, *) {
                    ToolbarTitleMenu {
                        dayPicker
                    }
                } else {
                    ToolbarItem(placement: .principal) {
                        dayPicker
                            .pickerStyle(.menu)
                            .font(.headline)
                    }
                }
            }

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
                                selectedFilter
                            },
                            set: { (type: ScheduleFilter) in
                                settings.setScheduleFilter(type, for: dataStore.metadata.identity)
                            }
                        )
                    ) {
                        Text("schedule.type.saved")
                            .tag(ScheduleFilter.saved)
                        if dataStore.automaticPlanning.isSupported {
                            Text("schedule.type.optimal")
                                .tag(ScheduleFilter.optimal)
                        }
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

    private func dayLabel(_ day: FestivalDay) -> String {
        day.scheduleLabel(calendar: dataStore.metadata.calendar, locale: locale)
    }

    private func ensureSelectedDay() {
        guard !days.isEmpty else { selectedDay = nil; return }
        if !days.contains(where: { $0.id == selectedDay }) {
            let now = Date.now
            selectedDay = days.first { now >= $0.interval.start && now < $0.interval.end }?.id ?? days.first?.id
        }
    }

}

enum ScheduleFilter: String, Equatable {
    case saved, optimal, interesting, all
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
