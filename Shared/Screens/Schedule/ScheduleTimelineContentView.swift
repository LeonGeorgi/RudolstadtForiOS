import SwiftUI
#if os(iOS)
import Observation
#else
import Combine
#endif

private let timelineGridLineThickness: CGFloat = 1
private let timelineTimeLabelTrailingPadding: CGFloat = 8
private let currentTimeIndicatorLabelHorizontalPadding: CGFloat = 6
private let currentTimeIndicatorLabelHeight: CGFloat = 18
private let timelineTimeLabelHeight: CGFloat = 14

private extension Color {
    static var timelineSeparator: Color {
        #if os(iOS)
        Color(uiColor: .separator)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }
}

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
    private let stageHeaderHeight: CGFloat = 60
    private let firstEventPadding: CGFloat = CGFloat(0)
    private let columnSpacing: CGFloat = CGFloat(5)

    private var timeColumnBoundaryWidth: CGFloat {
        timeWidth + columnSpacing / 2
    }

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
                        timelineFixedTop: stageHeaderHeight
                            + firstEventPadding,
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
                            stageHeaderHeight: stageHeaderHeight,
                            firstEventPadding: firstEventPadding,
                            columnSpacing: columnSpacing,
                            heightPerHour: heightPerHour
                        )
                        .overlay(alignment: .topLeading) {
                            ScheduleTimelineTimeColumn(
                                timeIntervals: timeIntervals,
                                scrollState: scrollState,
                                width: timeColumnBoundaryWidth,
                                timeWidth: timeWidth,
                                topPadding: stageHeaderHeight
                                    + firstEventPadding,
                                heightPerHour: heightPerHour,
                                currentTime: currentTimeLinePosition() == nil
                                    ? nil
                                    : currentTime
                            )
                            .allowsHitTesting(false)
                        }
                    }

                    Spacer()
                        .frame(height: stageHeaderHeight)
                        .background(Color(.systemBackground))
                        .allowsHitTesting(false)
                        .zIndex(4)

                    ScheduleTimelineGrid(
                        timeIntervals: timeIntervals,
                        scrollState: scrollState,
                        topPadding: stageHeaderHeight + firstEventPadding,
                        heightPerHour: heightPerHour
                    )
                    .zIndex(-0.5)

                    ScheduleTimelineStageSeparators(
                        stageCount: stages.count,
                        scrollState: scrollState,
                        columnWidth: columnWidth,
                        timeWidth: timeWidth,
                        topPadding: stageHeaderHeight + firstEventPadding,
                        columnSpacing: columnSpacing
                    )
                    .allowsHitTesting(false)
                    .zIndex(-1)

                    ScheduleTimelineStageHeaderBaseline(
                        topPadding: stageHeaderHeight + firstEventPadding
                    )
                    .allowsHitTesting(false)
                    .zIndex(6)

                    ScheduleTimelineStageHeaderTimeColumnMask(
                        width: timeColumnBoundaryWidth,
                        height: stageHeaderHeight + firstEventPadding
                    )
                    .allowsHitTesting(false)
                    .zIndex(5.5)

                    ScheduleTimelineTimeColumnSeparator(
                        timeWidth: timeWidth,
                        columnSpacing: columnSpacing
                    )
                    .allowsHitTesting(false)
                    .zIndex(6)

                    ScheduleTimelineStageHeaders(
                        stages: stages,
                        scrollState: scrollState,
                        columnWidth: columnWidth,
                        timeWidth: timeWidth,
                        stageHeaderHeight: stageHeaderHeight,
                        columnSpacing: columnSpacing
                    )
                    .zIndex(5)

                    if let position = currentTimeIndicatorPosition() {
                        ScheduleTimelineCurrentTimeLine(
                            currentTime: currentTime,
                            width: geo.size.width,
                            timeWidth: timeWidth,
                            heightPerHour: heightPerHour,
                            verticalPosition: position
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

    private func currentTimeIndicatorPosition() -> CGFloat? {
        let timelineTop = stageHeaderHeight + firstEventPadding
        return currentTimeLinePosition().map {
            $0 + timelineTop + scrollState.verticalOffset
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

        let elapsedHours = currentTime.timeIntervalSince(firstTimeInterval)
            / 3600
        return CGFloat(elapsedHours) * heightPerHour
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
    let stageHeaderHeight: CGFloat
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
                            height: stageHeaderHeight
                                + firstEventPadding
                                + heightPerHour * 0.25
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

private struct ScheduleTimelineTimeColumn: View {
    let timeIntervals: [Date]
    #if os(iOS)
    let scrollState: ScheduleTimelineScrollState
    #else
    @ObservedObject var scrollState: ScheduleTimelineScrollState
    #endif
    let width: CGFloat
    let timeWidth: CGFloat
    let topPadding: CGFloat
    let heightPerHour: CGFloat
    let currentTime: Date?

    var body: some View {
        content(obscuredTime: currentTime)
        .frame(width: width)
        .offset(x: -scrollState.horizontalOffset)
    }

    private func content(obscuredTime: Date?) -> some View {
        ZStack(alignment: .topLeading) {
            Color(.systemBackground)

            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: topPadding)

                ForEach(timeIntervals, id: \.self) { time in
                    Text(dateFormatter.string(from: time))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(
                            .trailing,
                            timelineTimeLabelTrailingPadding
                        )
                        .padding(.leading, 5)
                        .frame(
                            width: timeWidth,
                            height: 0.5 * heightPerHour,
                            alignment: .trailing
                        )
                        .scaledToFill()
                        .minimumScaleFactor(0.83)
                        .opacity(
                            isObscured(time, by: obscuredTime) ? 0 : 1
                        )
                }
            }
        }
    }

    private func isObscured(_ time: Date, by obscuredTime: Date?) -> Bool {
        guard let obscuredTime else { return false }

        let distanceInHours = abs(time.timeIntervalSince(obscuredTime)) / 3600
        let distanceInPoints = CGFloat(distanceInHours) * heightPerHour
        let overlapDistance = (
            currentTimeIndicatorLabelHeight + timelineTimeLabelHeight
        ) / 2
        return distanceInPoints < overlapDistance
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
                Rectangle()
                    .fill(Color.timelineSeparator)
                    .frame(height: timelineGridLineThickness)
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
    let stageHeaderHeight: CGFloat
    let columnSpacing: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScheduleTimelineStageSeparators(
                stageCount: stages.count,
                scrollState: scrollState,
                columnWidth: columnWidth,
                timeWidth: timeWidth,
                topPadding: 0,
                columnSpacing: columnSpacing
            )
            .allowsHitTesting(false)

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
                    .frame(width: columnWidth, height: stageHeaderHeight)
                }

                Spacer()
            }
            .offset(x: scrollState.horizontalOffset)
        }
        .frame(height: stageHeaderHeight)
    }

    private func stageHeader(_ stage: Stage) -> some View {
        VStack(alignment: .center, spacing: 5) {
            ScheduleTimelineStageNumber(stage: stage)

            Text(stage.localizedName)
                .frame(width: columnWidth - 1)
                .frame(maxHeight: .infinity, alignment: .top)
                .font(.caption2.weight(.medium))
                .minimumScaleFactor(0.8)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 5)
        .padding(.bottom, 6)
        .frame(width: columnWidth, height: stageHeaderHeight)
        .contentShape(Rectangle())
    }
}

private struct ScheduleTimelineStageNumber: View {
    let stage: Stage

    private let size: CGFloat = 18

    var body: some View {
        Group {
            if let stageNumber = stage.stageNumber {
                Text(String(stageNumber))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
            } else {
                Image(systemName: "mappin")
                    .font(.system(size: 9, weight: .semibold))
            }
        }
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .background(
            StageNumber.baseColor(for: stage.stageType),
            in: Circle()
        )
    }
}

private struct ScheduleTimelineStageSeparators: View {
    let stageCount: Int
    #if os(iOS)
    let scrollState: ScheduleTimelineScrollState
    #else
    @ObservedObject var scrollState: ScheduleTimelineScrollState
    #endif
    let columnWidth: CGFloat
    let timeWidth: CGFloat
    let topPadding: CGFloat
    let columnSpacing: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let separatorHeight = max(
                geometry.size.height - topPadding,
                0
            )

            ForEach(0...stageCount, id: \.self) { boundaryIndex in
                ScheduleTimelineStageSeparator()
                    .frame(height: separatorHeight)
                    .position(
                        x: timeWidth
                            + columnSpacing / 2
                            + CGFloat(boundaryIndex)
                                * (columnWidth + columnSpacing)
                            + scrollState.horizontalOffset,
                        y: topPadding + separatorHeight / 2
                    )
            }
        }
    }
}

private struct ScheduleTimelineStageSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.timelineSeparator)
            .frame(width: timelineGridLineThickness)
    }
}

private struct ScheduleTimelineStageHeaderBaseline: View {
    let topPadding: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: topPadding)

            Rectangle()
                .fill(Color.timelineSeparator)
                .frame(height: timelineGridLineThickness)

            Spacer()
        }
    }
}

private struct ScheduleTimelineStageHeaderTimeColumnMask: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Color(.systemBackground)
            .frame(width: width, height: height)
    }
}

private struct ScheduleTimelineTimeColumnSeparator: View {
    let timeWidth: CGFloat
    let columnSpacing: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: timeWidth)

            ScheduleTimelineStageSeparator()
                .frame(width: columnSpacing)

            Spacer()
        }
    }
}

private struct ScheduleTimelineCurrentTimeLine: View {
    let currentTime: Date
    let width: CGFloat
    let timeWidth: CGFloat
    let heightPerHour: CGFloat
    let verticalPosition: CGFloat

    private var lineLeadingInset: CGFloat {
        timeWidth
            - timelineTimeLabelTrailingPadding
            + currentTimeIndicatorLabelHorizontalPadding
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(dateFormatter.string(from: currentTime))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(
                    .horizontal,
                    currentTimeIndicatorLabelHorizontalPadding
                )
                .frame(
                    height: currentTimeIndicatorLabelHeight
                )
                .background(Color.red, in: Capsule())
                .frame(width: lineLeadingInset, alignment: .trailing)

            Rectangle()
                .fill(Color.red)
                .frame(
                    width: width - lineLeadingInset,
                    height: 2
                )
        }
        .frame(height: heightPerHour * 0.5)
        .offset(y: verticalPosition)
        .allowsHitTesting(false)
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
