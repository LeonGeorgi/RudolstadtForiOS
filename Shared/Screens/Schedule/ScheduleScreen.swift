import SwiftUI

struct ScheduleScreen: View {
    
    @Environment(\.festivalEdition) private var edition
    @Environment(\.festivalData) private var festivalData
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

    private var presenter: SchedulePresenter {
        SchedulePresenter(
            festivalData: festivalData,
            recommendationState: recommendations.state.recommendedEventIDs,
            scheduleFilterType: selectedFilter,
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
        .accessibilityIdentifier("schedule-screen")
        .onAppear {
            ensureSelectedDay()
        }
        .onChange(of: days.map(\.id), initial: false) { _, _ in
            ensureSelectedDay()
        }
        .navigationTitle("schedule.title")
        .navigationBarTitleDisplayMode(.inline)
        .scheduleDaySwitcherBar {
            if !days.map(\.id).isEmpty {
                VStack(spacing: 0) {
                    Picker("schedule.day.picker", selection: $selectedDay) {
                        ForEach(days) { day in
                            Text(day.label(calendar: dataStore.metadata.calendar))
                                .tag(Optional(day.id))
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(8)
                    .scheduleDaySwitcherStyle()
                    .padding(.horizontal)
                    .padding(.vertical, 4)
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

    private func ensureSelectedDay() {
        guard !days.isEmpty else { selectedDay = nil; return }
        if !days.contains(where: { $0.id == selectedDay }) {
            let now = Date.now
            selectedDay = days.first { now >= $0.interval.start && now < $0.interval.end }?.id ?? days.first?.id
        }
    }

}

enum ScheduleFilter: Equatable {
    case saved, optimal, interesting, all
}

private extension View {
    @ViewBuilder
    func scheduleDaySwitcherBar<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            safeAreaBar(edge: .top, spacing: 0, content: content)
        } else {
            safeAreaInset(edge: .top, spacing: 0, content: content)
        }
    }

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
