import SwiftUI
#if os(iOS)
import Observation
#else
import Combine
#endif

struct ScheduleTimelineContentView: View {
    // Preserve identity without making this parent observe offset changes.
    @State private var scrollState = ScheduleTimelineScrollState()
    @State private var currentTime: Date = Date()
    @State private var currentTimeUpdateTask: Task<Void, Never>?
    @State private var heightPerHour = ScheduleTimelineZoom.defaultHeightPerHour
    @State private var columnWidth = ScheduleTimelineZoom.defaultColumnWidth

    let timeIntervals: [Date]
    let stages: [(Stage, [EventOrGap])]
    let estimatedEventDurations: [Int: Int]?

    private let timeWidth: CGFloat = CGFloat(55)
    private let stageNameHeight: CGFloat = CGFloat(40)
    private let firstEventPadding: CGFloat = CGFloat(0)
    private let columnSpacing: CGFloat = CGFloat(5)
    private let stageHeaderCornerRadius: CGFloat = 12

    var body: some View {
        if stages.isEmpty {
            VStack {
                Spacer()

                Text("schedule.empty.description")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)

                Spacer()
            }
        } else {
            ZStack {
                Color(.systemBackground)
                .ignoresSafeArea()

                GeometryReader { geo in
                    ScheduleTimelineScrollView(
                        scrollState: scrollState,
                        heightPerHour: $heightPerHour,
                        columnWidth: $columnWidth,
                        timelineFixedTop: stageNameHeight
                            + firstEventPadding
                            + 25,
                        horizontalLayout: ScheduleTimelineHorizontalLayout(
                            stageCount: stages.count,
                            timeWidth: timeWidth,
                            columnSpacing: columnSpacing
                        )
                    ) {
                        ScheduleTimelineEventCanvas(
                            stages: stages,
                            estimatedEventDurations: estimatedEventDurations,
                            minimumSize: geo.size,
                            columnWidth: columnWidth,
                            timeWidth: timeWidth,
                            stageNameHeight: stageNameHeight,
                            firstEventPadding: firstEventPadding,
                            columnSpacing: columnSpacing,
                            heightPerHour: heightPerHour
                        )
                    }

                    Spacer()
                        .frame(width: timeWidth)
                        .background(Color(.systemBackground))
                        .allowsHitTesting(false)
                        .zIndex(1)

                    Spacer()
                        .frame(height: stageNameHeight + 25)
                        .background(Color(.systemBackground))
                        .allowsHitTesting(false)
                        .zIndex(4)

                    ScheduleTimelineTimeScale(
                        timeIntervals: timeIntervals,
                        scrollState: scrollState,
                        timeWidth: timeWidth,
                        topPadding: stageNameHeight + firstEventPadding + 25,
                        heightPerHour: heightPerHour
                    )
                    .allowsHitTesting(false)
                    .zIndex(2)

                    ScheduleTimelineGrid(
                        timeIntervals: timeIntervals,
                        scrollState: scrollState,
                        topPadding: stageNameHeight + firstEventPadding + 25,
                        heightPerHour: heightPerHour
                    )
                    .zIndex(-1)

                    ScheduleTimelineStageHeaders(
                        stages: stages,
                        scrollState: scrollState,
                        columnWidth: columnWidth,
                        timeWidth: timeWidth,
                        stageNameHeight: stageNameHeight,
                        columnSpacing: columnSpacing,
                        cornerRadius: stageHeaderCornerRadius
                    )
                    .zIndex(5)

                    currentTimeLinePosition().map { position in
                        ScheduleTimelineCurrentTimeLine(
                            currentTime: currentTime,
                            scrollState: scrollState,
                            width: geo.size.width,
                            timeWidth: timeWidth,
                            heightPerHour: heightPerHour,
                            verticalPosition: position
                                + stageNameHeight
                                + firstEventPadding
                                + 25
                        )
                        .zIndex(3)
                    }


                }
            }
            .onAppear {
                startUpdatingCurrentTime()
            }
            .onDisappear {
                currentTimeUpdateTask?.cancel()
                currentTimeUpdateTask = nil
            }
        }
    }

    func currentTimeLinePosition() -> CGFloat? {

        guard let firstTimeInterval = timeIntervals.first else { return nil }
        guard let lastTimeInterval = timeIntervals.last else { return nil }

        if currentTime < firstTimeInterval.addingTimeInterval(-30 * 60)
            || currentTime > lastTimeInterval.addingTimeInterval(30 * 60)
        {
            return nil
        }

        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentTime)
        let currentMinute = calendar.component(.minute, from: currentTime)
        let firstIntervalHour = calendar.component(
            .hour,
            from: firstTimeInterval
        )
        let firstIntervalMinute = calendar.component(
            .minute,
            from: firstTimeInterval
        )

        let hourDifference = currentHour - firstIntervalHour
        let minuteDifference = currentMinute - firstIntervalMinute

        let totalMinutesDifference = hourDifference * 60 + minuteDifference
        let position = CGFloat(totalMinutesDifference) / 60 * heightPerHour
        return position
    }

    func startUpdatingCurrentTime() {
        guard currentTimeUpdateTask == nil else { return }

        currentTimeUpdateTask = Task {
            while !Task.isCancelled {
                let calendar = Calendar.current
                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: Date().addingTimeInterval(60)
                )

                guard let nextMinute = calendar.date(from: components) else {
                    return
                }

                let interval = nextMinute.timeIntervalSince(Date())
                let sleepNanoseconds = UInt64(max(interval, 1) * 1_000_000_000)

                try? await Task.sleep(nanoseconds: sleepNanoseconds)
                if Task.isCancelled {
                    return
                }

                await MainActor.run {
                    currentTime = Date()
                }
            }
        }
    }
}

#if os(iOS)
@Observable
private final class ScheduleTimelineScrollState {
    private(set) var contentOffset: CGPoint = .zero
    private(set) var contentSize: CGSize = .zero
    private(set) var containerSize: CGSize = .zero

    var horizontalOffset: CGFloat { -contentOffset.x }
    var verticalOffset: CGFloat { -contentOffset.y }

    func update(
        contentOffset: CGPoint,
        contentSize: CGSize,
        containerSize: CGSize
    ) {
        if self.contentOffset != contentOffset {
            self.contentOffset = contentOffset
        }
        if self.contentSize != contentSize {
            self.contentSize = contentSize
        }
        if self.containerSize != containerSize {
            self.containerSize = containerSize
        }
    }
}
#else
private final class ScheduleTimelineScrollState: ObservableObject {
    @Published private(set) var horizontalOffset: CGFloat = 0
    @Published private(set) var verticalOffset: CGFloat = 0

    func update(to offset: CGPoint) {
        if horizontalOffset != offset.x {
            horizontalOffset = offset.x
        }
        if verticalOffset != offset.y {
            verticalOffset = offset.y
        }
    }
}
#endif

private struct ScheduleTimelineScrollView<Content: View>: View {
    let scrollState: ScheduleTimelineScrollState
    @Binding var heightPerHour: CGFloat
    @Binding var columnWidth: CGFloat
    let timelineFixedTop: CGFloat
    let horizontalLayout: ScheduleTimelineHorizontalLayout
    let content: Content

    #if os(iOS)
    @State private var scrollPosition = ScrollPosition()
    @State private var zoomGestureSession: ScheduleTimelineZoomGestureSession?
    @State private var zoomFrameScheduler = ScheduleTimelineZoomFrameScheduler()
    #endif

    init(
        scrollState: ScheduleTimelineScrollState,
        heightPerHour: Binding<CGFloat>,
        columnWidth: Binding<CGFloat>,
        timelineFixedTop: CGFloat,
        horizontalLayout: ScheduleTimelineHorizontalLayout,
        @ViewBuilder content: () -> Content
    ) {
        self.scrollState = scrollState
        self._heightPerHour = heightPerHour
        self._columnWidth = columnWidth
        self.timelineFixedTop = timelineFixedTop
        self.horizontalLayout = horizontalLayout
        self.content = content()
    }

    var body: some View {
        #if os(iOS)
        ScrollView([.horizontal, .vertical]) {
            content
                .disabled(zoomGestureSession != nil)
        }
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(
            for: ScheduleTimelineScrollMetrics.self
        ) { geometry in
            ScheduleTimelineScrollMetrics(
                contentOffset: CGPoint(
                    x: geometry.contentOffset.x
                        + geometry.contentInsets.leading,
                    y: geometry.contentOffset.y
                        + geometry.contentInsets.top
                ),
                contentSize: geometry.contentSize,
                containerSize: geometry.containerSize
            )
        } action: { _, metrics in
            scrollState.update(
                contentOffset: metrics.contentOffset,
                contentSize: metrics.contentSize,
                containerSize: metrics.containerSize
            )
        }
        .scrollDisabled(zoomGestureSession != nil)
        .simultaneousGesture(spatialEventGesture)
        .onDisappear {
            zoomFrameScheduler.cancel()
            zoomGestureSession = nil
        }
        #else
        ScrollView([.horizontal, .vertical]) {
            content
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ScheduleTimelineScrollOffsetPreferenceKey.self,
                            value: proxy.frame(
                                in: .named(ScheduleTimelineCoordinateSpace.name)
                            ).origin
                        )
                    }
                )
        }
        .coordinateSpace(name: ScheduleTimelineCoordinateSpace.name)
        .onPreferenceChange(ScheduleTimelineScrollOffsetPreferenceKey.self) {
            scrollState.update(to: $0)
        }
        #endif
    }

    #if os(iOS)
    private var spatialEventGesture: some Gesture {
        SpatialEventGesture()
            .onChanged(handleSpatialEvents)
            .onEnded { _ in finishZoom() }
    }

    private func handleSpatialEvents(_ events: SpatialEventCollection) {
        let activeTouches = events.filter {
            $0.kind == .touch && $0.phase == .active
        }
        guard activeTouches.count == 2 else {
            if zoomGestureSession != nil {
                finishZoom()
            }
            return
        }

        let touchPoints = activeTouches.map(\.location)
        guard let touchGeometry = ScheduleTimelineZoomTouchGeometry(
            firstTouch: touchPoints[0],
            secondTouch: touchPoints[1]
        ) else { return }

        let gestureSession = zoomGestureSession
            ?? ScheduleTimelineZoomGestureSession(
                zoomSession: makeZoomSession(
                    anchorViewportPoint: touchGeometry.centroid
                ),
                initialTouchGeometry: touchGeometry
            )
        zoomGestureSession = gestureSession
        let magnification = touchGeometry.magnification(
            relativeTo: gestureSession.initialTouchGeometry
        )

        zoomFrameScheduler.submit {
            applyZoom(
                magnification: magnification,
                centroid: touchGeometry.centroid,
                session: gestureSession.zoomSession
            )
        }
    }

    private func finishZoom() {
        guard zoomGestureSession != nil else { return }

        zoomFrameScheduler.finish {
            zoomGestureSession = nil
        }
    }

    private func applyZoom(
        magnification: ScheduleTimelineZoomMagnification,
        centroid: CGPoint,
        session: ScheduleTimelineZoomSession
    ) {
        let update = session.update(
            for: magnification,
            anchorViewportPoint: centroid
        )
        let current = ScheduleTimelineZoomUpdate(
            heightPerHour: heightPerHour,
            columnWidth: columnWidth,
            contentOffset: scrollState.contentOffset
        )
        guard zoomFrameScheduler.shouldApply(
            update,
            relativeTo: current
        ) else {
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.scrollContentOffsetAdjustmentBehavior = .disabled
        withTransaction(transaction) {
            heightPerHour = update.heightPerHour
            columnWidth = update.columnWidth
            scrollPosition.scrollTo(point: update.contentOffset)
        }
    }

    private func makeZoomSession(
        anchorViewportPoint: CGPoint
    ) -> ScheduleTimelineZoomSession {
        let containerWidth = max(scrollState.containerSize.width, 1)
        let containerHeight = max(scrollState.containerSize.height, 1)
        let containerSize = CGSize(
            width: containerWidth,
            height: containerHeight
        )
        let contentSize = CGSize(
            width: max(scrollState.contentSize.width, containerWidth),
            height: max(scrollState.contentSize.height, containerHeight)
        )
        let clampedAnchorPoint = CGPoint(
            x: min(
                max(anchorViewportPoint.x, 0),
                containerSize.width
            ),
            y: min(
                max(anchorViewportPoint.y, 0),
                containerSize.height
            )
        )
        let contentOffset = CGPoint(
            x: max(scrollState.contentOffset.x, 0),
            y: max(scrollState.contentOffset.y, 0)
        )

        return ScheduleTimelineZoomSession(
            baseHeightPerHour: heightPerHour,
            baseColumnWidth: columnWidth,
            contentOffset: contentOffset,
            contentSize: contentSize,
            containerSize: containerSize,
            anchorViewportPoint: clampedAnchorPoint,
            timelineFixedTop: timelineFixedTop,
            horizontalLayout: horizontalLayout
        )
    }
    #endif
}

#if os(iOS)
private struct ScheduleTimelineZoomGestureSession {
    let zoomSession: ScheduleTimelineZoomSession
    let initialTouchGeometry: ScheduleTimelineZoomTouchGeometry
}

private struct ScheduleTimelineScrollMetrics: Equatable {
    let contentOffset: CGPoint
    let contentSize: CGSize
    let containerSize: CGSize
}
#endif

#if !os(iOS)
private enum ScheduleTimelineCoordinateSpace {
    static let name = "scheduleTimelineScrollView"
}

private struct ScheduleTimelineScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero

    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}
#endif

private struct ScheduleTimelineEventCanvas: View {
    @EnvironmentObject private var profile: FestivalProfileStore

    let stages: [(Stage, [EventOrGap])]
    let estimatedEventDurations: [Int: Int]?
    let minimumSize: CGSize
    let columnWidth: CGFloat
    let timeWidth: CGFloat
    let stageNameHeight: CGFloat
    let firstEventPadding: CGFloat
    let columnSpacing: CGFloat
    let heightPerHour: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            Spacer()
                .frame(width: timeWidth)

            ForEach(stages, id: \.0.id) { (_, stageEvents) in
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                        .frame(
                            height: stageNameHeight
                                + firstEventPadding
                                + heightPerHour * 0.25
                                + 25
                        )

                    events(stageEvents)

                    Spacer()
                }
            }

            Spacer()
        }
        .frame(
            minWidth: minimumSize.width,
            minHeight: minimumSize.height,
            alignment: .topLeading
        )
    }

    private func events(_ stageEvents: [EventOrGap]) -> some View {
        ForEach(stageEvents.indices, id: \.self) { index in
            switch stageEvents[index] {
            case .event(let event):
                let eventDuration = estimatedEventDurations?[event.id] ?? 60
                let eventHeight = CGFloat(eventDuration) / 60 * heightPerHour
                ScheduleTimelineEventCell(
                    width: columnWidth,
                    height: eventHeight - 2,
                    event: event,
                    eventDurationMinutes: eventDuration,
                    isSaved: profile.isEventSaved(event.id),
                    artistRating: profile.rating(for: event.artist.id),
                    artistIconName: profile.iconName(forArtistID: event.artist.id),
                    friendProfilesWhoSavedEvent: profile.friendProfilesSavingEvent(event.id),
                    onToggleSaved: { profile.toggleSavedEvent(event) }
                )
                .padding(.vertical, 1)
            case .gap(let gap):
                let gapHeight = CGFloat(gap.duration / (60 * 60))
                    * heightPerHour
                Spacer()
                    .frame(width: columnWidth, height: gapHeight)
            }
        }
    }
}

private struct ScheduleTimelineTimeScale: View {
    let timeIntervals: [Date]
    #if os(iOS)
    let scrollState: ScheduleTimelineScrollState
    #else
    @ObservedObject var scrollState: ScheduleTimelineScrollState
    #endif
    let timeWidth: CGFloat
    let topPadding: CGFloat
    let heightPerHour: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: topPadding)

            ForEach(timeIntervals, id: \.self) { time in
                Text(dateFormatter.string(from: time))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .padding(.trailing, 8)
                    .padding(.leading, 5)
                    .frame(
                        width: timeWidth,
                        height: 0.5 * heightPerHour,
                        alignment: .trailing
                    )
                    .scaledToFill()
                    .minimumScaleFactor(0.83)
            }
        }
        .offset(y: scrollState.verticalOffset)
    }
}

private struct ScheduleTimelineGrid: View {
    let timeIntervals: [Date]
    #if os(iOS)
    let scrollState: ScheduleTimelineScrollState
    #else
    @ObservedObject var scrollState: ScheduleTimelineScrollState
    #endif
    let topPadding: CGFloat
    let heightPerHour: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(timeIntervals, id: \.self) { _ in
                Divider()
                    .frame(height: heightPerHour * 0.5)
                    .padding(0)
            }
        }
        .padding(.top, topPadding)
        .offset(y: scrollState.verticalOffset)
    }
}

private struct ScheduleTimelineStageHeaders: View {
    let stages: [(Stage, [EventOrGap])]
    #if os(iOS)
    let scrollState: ScheduleTimelineScrollState
    #else
    @ObservedObject var scrollState: ScheduleTimelineScrollState
    #endif
    let columnWidth: CGFloat
    let timeWidth: CGFloat
    let stageNameHeight: CGFloat
    let columnSpacing: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            Spacer()
                .frame(width: timeWidth)

            ForEach(stages, id: \.0.id) { (stage, _) in
                NavigationLink(
                    value: AppNavigationRoute.stage(
                        id: stage.id,
                        highlightedEventId: nil
                    )
                ) {
                    stageHeader(stage)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        StageMapView.openInMaps(stage: stage)
                    } label: {
                        Text("schedule.context.open_in_maps")
                        Image(systemName: "map")
                    }
                } preview: {
                    StagePreview(stage: stage)
                }
            }

            Spacer()
        }
        .offset(x: scrollState.horizontalOffset)
    }

    private func stageHeader(_ stage: Stage) -> some View {
        VStack(alignment: .center, spacing: 0) {
            StageNumber(
                stage: stage,
                size: 18,
                font: .system(size: 11, weight: .heavy, design: .rounded)
            )
            .padding(.top, 4)
            .padding(.bottom, 4)

            Text(stage.localizedName)
                .frame(
                    width: columnWidth - 1,
                    height: stageNameHeight,
                    alignment: .top
                )
                .font(.system(size: 10, weight: .semibold))
                .minimumScaleFactor(0.85)
                .lineLimit(3)
                .multilineTextAlignment(.center)
        }
        .frame(width: columnWidth, height: stageNameHeight + 20)
        .background(Color(.secondarySystemBackground))
        .clipShape(
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
        )
    }
}

private struct ScheduleTimelineCurrentTimeLine: View {
    let currentTime: Date
    #if os(iOS)
    let scrollState: ScheduleTimelineScrollState
    #else
    @ObservedObject var scrollState: ScheduleTimelineScrollState
    #endif
    let width: CGFloat
    let timeWidth: CGFloat
    let heightPerHour: CGFloat
    let verticalPosition: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(dateFormatter.string(from: currentTime))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.red)
                .padding(.horizontal, 10)
                .frame(
                    width: timeWidth,
                    height: 0.5 * heightPerHour,
                    alignment: .trailing
                )
                .scaledToFill()
                .minimumScaleFactor(0.83)

            Rectangle()
                .fill(Color.red)
                .frame(
                    width: width - timeWidth,
                    height: 1
                )
        }
        .frame(height: heightPerHour * 0.5)
        .offset(y: verticalPosition + scrollState.verticalOffset)
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
}()

#if DEBUG
@MainActor
private enum ScheduleTimelineContentViewPreviewData {
    static let previewDay = 4

    static func events(from environment: PreviewAppEnvironment) -> [Event] {
        environment.festivalData.events.filter { event in
            event.festivalDay == previewDay
        }
    }

    static func timeIntervals(
        events: [Event],
        estimatedEventDurations: [Int: Int]?
    ) -> [Date] {
        guard let firstEventDate = events.map(\.date).min() else {
            return []
        }
        guard let lastEvent = events.max(by: { first, second in
            first.endDate(
                durationInMinutes: estimatedEventDurations?[first.id] ?? 60
            )
                < second.endDate(
                    durationInMinutes: estimatedEventDurations?[second.id] ?? 60
                )
        }) else {
            return []
        }

        let lastEventEndDate = lastEvent.endDate(
            durationInMinutes: estimatedEventDurations?[lastEvent.id] ?? 60
        )
        return halfHourlyDates(
            startDate: firstEventDate,
            endDate: lastEventEndDate
        )
    }

    static func stages(
        events: [Event],
        estimatedEventDurations: [Int: Int]?
    ) -> [(Stage, [EventOrGap])] {
        Dictionary(grouping: events) { event in
            event.stage
        }
        .map { stage, events in
            (
                stage,
                eventGapList(
                    events: events,
                    firstEventTime: events.map(\.date).min() ?? Date(),
                    estimatedEventDurations: estimatedEventDurations
                )
            )
        }
        .sorted { first, second in
            first.0.stageNumber ?? 1000 < second.0.stageNumber ?? 1000
        }
    }

    private static func eventGapList(
        events: [Event],
        firstEventTime: Date,
        estimatedEventDurations: [Int: Int]?
    ) -> [EventOrGap] {
        let sortedEvents = events.sorted { first, second in
            first.date < second.date
        }
        var lastTime = firstEventTime
        var result: [EventOrGap] = []

        for event in sortedEvents {
            if event.date < lastTime {
                continue
            }

            if lastTime < event.date {
                result.append(
                    .gap(Gap(duration: event.date.timeIntervalSince(lastTime)))
                )
            }

            result.append(.event(event))
            let eventEnd = event.endDate(
                durationInMinutes: estimatedEventDurations?[event.id] ?? 60
            )
            if eventEnd > lastTime {
                lastTime = eventEnd
            }
        }

        return result
    }

    private static func halfHourlyDates(
        startDate: Date,
        endDate: Date
    ) -> [Date] {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: startDate
        )
        let roundedMinute = ((startComponents.minute ?? 0) / 30) * 30
        let roundedStartDate = calendar.date(
            from: DateComponents(
                year: startComponents.year,
                month: startComponents.month,
                day: startComponents.day,
                hour: startComponents.hour,
                minute: roundedMinute
            )
        ) ?? startDate

        var dates: [Date] = []
        var currentDate = roundedStartDate
        while currentDate < endDate {
            dates.append(currentDate)
            currentDate = currentDate.addingTimeInterval(30 * 60)
        }
        dates.append(currentDate)
        return dates
    }
}

struct ScheduleTimelineContentView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        let environment = PreviewMockData.makeEnvironment(
            suiteName: "ScheduleTimelineContentViewPreview"
        )
        let events = ScheduleTimelineContentViewPreviewData.events(
            from: environment
        )
        let estimatedEventDurations = environment.dataStore.estimatedEventDurationsByEventID

        NavigationStack {
            ScheduleTimelineContentView(
                timeIntervals: ScheduleTimelineContentViewPreviewData.timeIntervals(
                    events: events,
                    estimatedEventDurations: estimatedEventDurations
                ),
                stages: ScheduleTimelineContentViewPreviewData.stages(
                    events: events,
                    estimatedEventDurations: estimatedEventDurations
                ),
                estimatedEventDurations: estimatedEventDurations
            )
            .navigationDestination(for: AppNavigationRoute.self) { _ in
                EmptyView()
            }
        }
        .previewEnvironment(environment)
    }
}
#endif
