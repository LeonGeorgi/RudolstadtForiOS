import RudolstadtCore
import SwiftUI

#if os(iOS)
    import Observation
#else
    import Combine
#endif

private let timelineGridLineThickness: CGFloat = 1
private let timelineStageHeaderHeight: CGFloat = 60
private let timelineTimeLabelTrailingPadding: CGFloat = 8
private let currentTimeIndicatorLabelHorizontalPadding: CGFloat = 6
private let currentTimeIndicatorLabelHeight: CGFloat = 18
private let timelineTimeLabelHeight: CGFloat = 14

extension Color {
    fileprivate static var timelineSeparator: Color {
        #if os(iOS)
            Color(uiColor: .separator)
        #else
            Color(nsColor: .separatorColor)
        #endif
    }
}

struct ScheduleTimelineContentView: View {
    @Environment(\.locale) private var locale
    @Environment(\.festivalData) private var festivalData
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var heightPerHour = ScheduleTimelineZoom.defaultHeightPerHour
    @State private var columnWidth = ScheduleTimelineZoom.defaultColumnWidth
    @State private var enteringAtEnd: String?
    @State private var dayPullDirection: ScheduleTimelineDayPull.Direction = .next

    let days: [ProgramTimelineDay]
    @Binding var selectedDay: String?
    let estimatedEventDurations: [Int: Int]?
    let onShowEndTimeInformation: () -> Void

    var body: some View {
        ZStack {
            selectedDayContent
        }
        .clipped()
    }

    private var dayTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: dayPullDirection == .next ? .bottom : .top)
                .combined(with: .opacity),
            removal: .opacity)
    }

    @ViewBuilder
    private var selectedDayContent: some View {
        if let index = days.firstIndex(where: { $0.day.date.id == selectedDay })
            ?? days.indices.first
        {
            let day = days[index]
            ScheduleTimelineSelectedDay(
                day: day, heightPerHour: $heightPerHour, columnWidth: $columnWidth,
                estimatedEventDurations: estimatedEventDurations,
                previousDayLabel: dayLabel(at: index - 1), nextDayLabel: dayLabel(at: index + 1),
                initialAtEnd: enteringAtEnd == day.day.date.id,
                onShowEndTimeInformation: onShowEndTimeInformation,
                onDayPull: { direction in
                    let destination = index + (direction == .next ? 1 : -1)
                    guard days.indices.contains(destination) else { return }
                    let id = days[destination].day.date.id
                    dayPullDirection = direction
                    withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.32)) {
                        enteringAtEnd = direction == .previous ? id : nil
                        selectedDay = id
                    }
                }
            )
            .id(day.day.date.id)
            .transition(dayTransition)
            .onChange(of: selectedDay) { _, id in
                if enteringAtEnd != id { enteringAtEnd = nil }
            }
        } else {
            Text("schedule.empty.description")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
    private func dayLabel(at index: Int) -> String? {
        guard days.indices.contains(index) else { return nil }
        return days[index].day.native.scheduleLabel(
            calendar: festivalData.metadata?.calendar ?? FestivalDateUtilities.festivalCalendar,
            locale: locale)
    }

}

private struct ScheduleTimelineSelectedDay: View {
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var friends: FriendProfilesStore
    @EnvironmentObject private var settings: UserSettings
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    let day: ProgramTimelineDay
    @Binding var heightPerHour: CGFloat
    @Binding var columnWidth: CGFloat
    let estimatedEventDurations: [Int: Int]?
    let previousDayLabel: String?
    let nextDayLabel: String?
    let initialAtEnd: Bool
    let onShowEndTimeInformation: () -> Void
    let onDayPull: (ScheduleTimelineDayPull.Direction) -> Void

    var body: some View {
        let formatter = ListFormatter()
        formatter.locale = locale
        let stages = day.timeline.nativeColumns(locale: locale) { event in
            ScheduleTimelineEventPresentation(
                event: event, duration: estimatedEventDurations?[event.id] ?? 60,
                contextPreviewState: EventContextPreviewState(
                    event: event, profile: profile, friends: friends, settings: settings),
                locale: locale, colorScheme: colorScheme, countryFormatter: formatter)
        }
        let timeIntervals = day.timeline.nativeTicks
        return ScheduleTimelineDayView(
            timeIntervals: timeIntervals, timeLabels: timeIntervals.map(dateFormatter.string),
            stages: stages,
            onToggleSaved: { profile.toggleSavedEvent($0) },
            heightPerHour: $heightPerHour, columnWidth: $columnWidth,
            previousDayLabel: previousDayLabel, nextDayLabel: nextDayLabel,
            initialAtEnd: initialAtEnd, onShowEndTimeInformation: onShowEndTimeInformation,
            onDayPull: onDayPull)
    }
}

private struct ScheduleTimelineDayView: View {
    @State private var scrollState = ScheduleTimelineScrollState()
    let timeIntervals: [Date]
    let timeLabels: [String]
    let stages: [ScheduleTimelineStagePresentation]
    let onToggleSaved: (Event) -> Void
    @Binding var heightPerHour: CGFloat
    @Binding var columnWidth: CGFloat
    let previousDayLabel: String?
    let nextDayLabel: String?
    let initialAtEnd: Bool
    let onShowEndTimeInformation: () -> Void
    let onDayPull: (ScheduleTimelineDayPull.Direction) -> Void

    private let timeWidth: CGFloat = 55
    private let columnSpacing: CGFloat = 5
    private let stageHeaderHeight = timelineStageHeaderHeight

    var body: some View {
        GeometryReader { geometry in
            let layout = ScheduleTimelineDayLayout(
                hours: max(CGFloat(timeIntervals.count) / 2, 1.5),
                headerHeight: stageHeaderHeight,
                viewportHeight: geometry.size.height)
            let horizontalLayout = ScheduleTimelineHorizontalLayout(
                stageCount: stages.count,
                timeWidth: timeWidth, columnSpacing: columnSpacing)
            let width = horizontalLayout.contentWidth(
                columnWidth: columnWidth, minimumWidth: geometry.size.width)
            ScheduleTimelineScrollView(
                scrollState: scrollState, heightPerHour: $heightPerHour,
                columnWidth: $columnWidth, horizontalLayout: horizontalLayout, dayLayout: layout,
                previousDayLabel: previousDayLabel, nextDayLabel: nextDayLabel,
                initialAtEnd: initialAtEnd, onDayPull: onDayPull
            ) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ScheduleTimelineDayBody(
                            timeIntervals: timeIntervals, timeLabels: timeLabels, stages: stages,
                            onToggleSaved: onToggleSaved, scrollState: scrollState, width: width,
                            height: layout.bodyHeight(heightPerHour: heightPerHour),
                            viewportWidth: geometry.size.width, columnWidth: columnWidth,
                            timeWidth: timeWidth, columnSpacing: columnSpacing,
                            heightPerHour: heightPerHour
                        )
                        .background(Color(.systemBackground))
                    } header: {
                        ScheduleTimelineStageBar(
                            stages: stages, scrollState: scrollState,
                            width: width, columnWidth: columnWidth, timeWidth: timeWidth,
                            columnSpacing: columnSpacing, height: stageHeaderHeight,
                            onShowEndTimeInformation: onShowEndTimeInformation)
                    }
                }
                .frame(width: width, alignment: .leading)
            } pullContent: { hint in
                if let hint,
                    let dayLabel = hint.direction == .previous ? previousDayLabel : nextDayLabel
                {
                    let isPrevious = hint.direction == .previous
                    pullContent(
                        hint: hint, dayLabel: dayLabel, width: width,
                        viewportSize: geometry.size, stageCount: stages.count
                    )
                    .frame(height: 0, alignment: isPrevious ? .bottom : .top)
                    .offset(
                        x: scrollState.horizontalOffset,
                        y: isPrevious
                            ? stageHeaderHeight - scrollState.topOverscroll
                            : geometry.size.height - scrollState.bottomOverscroll
                    )
                    .frame(
                        width: geometry.size.width, height: geometry.size.height,
                        alignment: .topLeading
                    )
                    .clipped()
                }
            }
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    Rectangle().fill(Color.timelineSeparator).frame(height: timelineGridLineThickness)
                    Spacer(minLength: 0)
                    Rectangle().fill(Color.timelineSeparator).frame(height: timelineGridLineThickness)
                }
                .frame(height: stageHeaderHeight)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .background(Color(.systemBackground))
    }

    private func pullContent(
        hint: ScheduleTimelineDayPull.Hint, dayLabel: String, width: CGFloat,
        viewportSize: CGSize, stageCount: Int
    ) -> some View {
        let timeColumnWidth = timeWidth + columnSpacing / 2
        let grid = ScheduleTimelineStageSeparatorGrid(
            stageCount: stageCount, columnWidth: columnWidth, timeWidth: timeWidth,
            topPadding: 0, columnSpacing: columnSpacing, horizontalOffset: 0)
        .frame(width: width, height: viewportSize.height)
        .clipped()
        .mask { ScheduleTimelineSeparatorFade(topFadeHeight: 32) }
        .background(alignment: .topLeading) {
            ScheduleTimelineViewportGrid(
                scrollState: scrollState,
                rowCount: Int(ceil(viewportSize.height / (heightPerHour * 0.5))),
                width: viewportSize.width, height: viewportSize.height,
                heightPerHour: heightPerHour, topFadeHeight: 32)
        }
        .opacity(Double(hint.opacity))
        .accessibilityHidden(true)

        // Decoration follows the native scroll offset without extending the scroll bounds.
        return VStack(spacing: 0) {
            if hint.direction == .previous { grid }
            ScheduleTimelineDayPullHint(hint: hint, dayLabel: dayLabel)
                .frame(width: max(viewportSize.width - timeColumnWidth, 0))
                .offset(x: timeColumnWidth - scrollState.horizontalOffset)
                .frame(width: width, alignment: .leading)
            if hint.direction == .next { grid }
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .topLeading) {
            ScheduleTimelineTimeColumn(
                timeIntervals: [], timeLabels: [], scrollState: scrollState,
                width: timeColumnWidth, timeWidth: timeWidth,
                topPadding: 0, heightPerHour: heightPerHour, currentTime: nil)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topLeading) {
            ScheduleTimelineTimeColumnSeparator(
                timeWidth: timeWidth, columnSpacing: columnSpacing
            )
            .mask { ScheduleTimelineSeparatorFade(topFadeHeight: 32) }
            .opacity(Double(hint.opacity))
            .offset(x: -scrollState.horizontalOffset)
            .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
    }
}

private struct ScheduleTimelineStageBar: View {
    let stages: [ScheduleTimelineStagePresentation]
    #if os(iOS)
        let scrollState: ScheduleTimelineScrollState
    #else
        @ObservedObject var scrollState: ScheduleTimelineScrollState
    #endif
    let width: CGFloat
    let columnWidth: CGFloat
    let timeWidth: CGFloat
    let columnSpacing: CGFloat
    let height: CGFloat
    let onShowEndTimeInformation: () -> Void

    var body: some View {
        ScheduleTimelineStageHeaders(
            stages: stages, columnWidth: columnWidth,
            timeWidth: timeWidth, stageHeaderHeight: height, columnSpacing: columnSpacing
        )
        .overlay(alignment: .topLeading) {
            Button(action: onShowEndTimeInformation) {
                Image(systemName: "info.circle").frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .frame(width: timeWidth + columnSpacing / 2, height: height)
            .background(Color(.systemBackground))
            .overlay(alignment: .trailing) { ScheduleTimelineStageSeparator() }
            .offset(x: -scrollState.horizontalOffset)
            .accessibilityLabel(Text("schedule.endtimes.notice"))
            .accessibilityHint(Text("schedule.endtimes.notice.hint"))
        }
        .frame(width: width, height: height)
        .background(Color(.systemBackground))
        .offset(y: scrollState.topOverscroll)
    }
}

private struct ScheduleTimelineDayBody: View {
    let timeIntervals: [Date]
    let timeLabels: [String]
    let stages: [ScheduleTimelineStagePresentation]
    let onToggleSaved: (Event) -> Void
    #if os(iOS)
        let scrollState: ScheduleTimelineScrollState
    #else
        @ObservedObject var scrollState: ScheduleTimelineScrollState
    #endif
    let width: CGFloat
    let height: CGFloat
    let viewportWidth: CGFloat
    let columnWidth: CGFloat
    let timeWidth: CGFloat
    let columnSpacing: CGFloat
    let heightPerHour: CGFloat

    var body: some View {
        if stages.isEmpty {
            Text("schedule.empty.description")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: viewportWidth, height: height)
                .offset(x: -scrollState.horizontalOffset)
                .frame(width: width, alignment: .leading)
        } else {
            let gridHeight = CGFloat(timeIntervals.count) * heightPerHour * 0.5
            TimelineView(.everyMinute) { context in
                let position = currentTimeLinePosition(at: context.date)
                ScheduleTimelineEventCanvas(
                    stages: stages, onToggleSaved: onToggleSaved,
                    minimumSize: CGSize(width: width, height: height), columnWidth: columnWidth,
                    timeWidth: timeWidth, stageHeaderHeight: 0, firstEventPadding: 0,
                    columnSpacing: columnSpacing, heightPerHour: heightPerHour
                )
                .background(alignment: .topLeading) {
                    ScheduleTimelineStageSeparatorGrid(
                        stageCount: stages.count, columnWidth: columnWidth, timeWidth: timeWidth,
                        topPadding: 0, columnSpacing: columnSpacing, horizontalOffset: 0
                    )
                    .frame(height: gridHeight)
                    .mask { ScheduleTimelineDayGridFade(scrollState: scrollState) }
                }
                .frame(width: width, height: height, alignment: .topLeading)
                // Pinned overlays must remain visible beyond the content edge during rubberbanding.
                .clipped()
                .background(alignment: .topLeading) {
                    ScheduleTimelineViewportGrid(
                        scrollState: scrollState, rowCount: timeIntervals.count,
                        width: viewportWidth, height: gridHeight, heightPerHour: heightPerHour)
                }
                .overlay(alignment: .topLeading) {
                    ScheduleTimelineTimeColumn(
                        timeIntervals: timeIntervals, timeLabels: timeLabels,
                        scrollState: scrollState,
                        width: timeWidth + columnSpacing / 2, timeWidth: timeWidth,
                        topPadding: 0, heightPerHour: heightPerHour,
                        currentTime: position == nil ? nil : context.date
                    )
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    ScheduleTimelineTimeColumnSeparator(
                        timeWidth: timeWidth, columnSpacing: columnSpacing
                    )
                    .frame(height: gridHeight)
                    .mask { ScheduleTimelineDayGridFade(scrollState: scrollState) }
                    .offset(x: -scrollState.horizontalOffset)
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    if let position {
                        ScheduleTimelineCurrentTimeLine(
                            currentTime: context.date, scrollState: scrollState,
                            width: viewportWidth,
                            timeWidth: timeWidth, heightPerHour: heightPerHour,
                            verticalPosition: position)
                    }
                }
            }
            .frame(width: width, height: height)
        }
    }

    private func currentTimeLinePosition(at date: Date) -> CGFloat? {
        guard let first = timeIntervals.first, let last = timeIntervals.last,
            date >= first.addingTimeInterval(-1800), date <= last.addingTimeInterval(1800)
        else { return nil }
        return CGFloat(date.timeIntervalSince(first) / 3600) * heightPerHour
    }
}

#if os(iOS)
    @Observable
    private final class ScheduleTimelineScrollState {
        private(set) var contentOffset: CGPoint = .zero
        private(set) var contentSize: CGSize = .zero
        private(set) var containerSize: CGSize = .zero

        private(set) var horizontalOffset: CGFloat = 0
        private(set) var topOverscroll: CGFloat = 0

        var bottomOverscroll: CGFloat {
            max(contentOffset.y - max(contentSize.height - containerSize.height, 0), 0)
        }

        func update(
            contentOffset: CGPoint,
            contentSize: CGSize,
            containerSize: CGSize
        ) {
            let topOverscroll = min(contentOffset.y, 0)
            if self.topOverscroll != topOverscroll {
                self.topOverscroll = topOverscroll
            }
            if horizontalOffset != -contentOffset.x {
                horizontalOffset = -contentOffset.x
            }
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
        @Published private(set) var topOverscroll: CGFloat = 0
        let bottomOverscroll: CGFloat = 0

        func update(to offset: CGPoint) {
            let topOverscroll = min(-offset.y, 0)
            if self.topOverscroll != topOverscroll {
                self.topOverscroll = topOverscroll
            }
            if horizontalOffset != offset.x {
                horizontalOffset = offset.x
            }
        }
    }
#endif

private struct ScheduleTimelineScrollView<Content: View, PullContent: View>: View {
    let scrollState: ScheduleTimelineScrollState
    @Binding var heightPerHour: CGFloat
    @Binding var columnWidth: CGFloat
    let horizontalLayout: ScheduleTimelineHorizontalLayout
    let dayLayout: ScheduleTimelineDayLayout
    @State private var dayPull = ScheduleTimelineDayPull()
    let previousDayLabel: String?
    let nextDayLabel: String?
    let initialAtEnd: Bool
    let onDayPull: (ScheduleTimelineDayPull.Direction) -> Void
    let content: Content
    let pullContent: (ScheduleTimelineDayPull.Hint?) -> PullContent

    #if os(iOS)
        @State private var scrollPosition = ScrollPosition()
        @State private var zoomGestureSession: ScheduleTimelineZoomGestureSession?
        @State private var zoomFrameScheduler = ScheduleTimelineZoomFrameScheduler()
    #endif

    init(
        scrollState: ScheduleTimelineScrollState,
        heightPerHour: Binding<CGFloat>,
        columnWidth: Binding<CGFloat>,
        horizontalLayout: ScheduleTimelineHorizontalLayout,
        dayLayout: ScheduleTimelineDayLayout,
        previousDayLabel: String?,
        nextDayLabel: String?,
        initialAtEnd: Bool,
        onDayPull: @escaping (ScheduleTimelineDayPull.Direction) -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder pullContent: @escaping (ScheduleTimelineDayPull.Hint?) -> PullContent
    ) {
        self.scrollState = scrollState
        self._heightPerHour = heightPerHour
        self._columnWidth = columnWidth
        self.horizontalLayout = horizontalLayout
        self.dayLayout = dayLayout
        self.previousDayLabel = previousDayLabel
        self.nextDayLabel = nextDayLabel
        self.initialAtEnd = initialAtEnd
        self.onDayPull = onDayPull
        self.content = content()
        self.pullContent = pullContent
    }

    var body: some View {
        #if os(iOS)
            ScrollView([.horizontal, .vertical]) {
                content.disabled(zoomGestureSession != nil)
            }
            .scrollBounceBehavior(.always, axes: .vertical)
            .defaultScrollAnchor(initialAtEnd ? .bottomLeading : .topLeading, for: .initialOffset)
            .onScrollPhaseChange { old, new, context in
                if old == .interacting {
                    updateDayPull(context.geometry)
                    let direction = dayPull.end()
                    if zoomGestureSession == nil, new == .idle || new == .decelerating,
                        let direction
                    {
                        onDayPull(direction)
                    }
                }
                if new == .interacting { dayPull.begin() }
            }
            .sensoryFeedback(trigger: dayPull.hint?.isReady == true) { _, isReady in
                isReady ? .impact(weight: .heavy, intensity: 1) : nil
            }
            .scrollPosition($scrollPosition)
            .onScrollGeometryChange(
                for: ScheduleTimelineScrollMetrics.self
            ) { geometry in
                ScheduleTimelineScrollMetrics(geometry: geometry)
            } action: { _, metrics in
                scrollState.update(
                    contentOffset: metrics.contentOffset,
                    contentSize: metrics.contentSize,
                    containerSize: metrics.containerSize
                )
                if zoomGestureSession == nil {
                    dayPull.update(
                        offset: metrics.contentOffset.y,
                        maximumOffset: metrics.maximumVerticalOffset,
                        hasPreviousDay: previousDayLabel != nil, hasNextDay: nextDayLabel != nil)
                }
            }
            .scrollDisabled(zoomGestureSession != nil)
            .simultaneousGesture(spatialEventGesture)
            .onDisappear {
                zoomFrameScheduler.cancel()
                zoomGestureSession = nil
                dayPull.cancel()
            }
            .background(alignment: .topLeading) { pullContent(dayPull.hint) }
        #else
            ScrollView([.horizontal, .vertical]) {
                content.background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ScheduleTimelineScrollOffsetPreferenceKey.self,
                            value: proxy.frame(in: .named(ScheduleTimelineCoordinateSpace.name))
                                .origin)
                    })
            }
            .coordinateSpace(name: ScheduleTimelineCoordinateSpace.name)
            .onPreferenceChange(ScheduleTimelineScrollOffsetPreferenceKey.self) {
                scrollState.update(to: $0)
            }
            .background(alignment: .topLeading) { pullContent(dayPull.hint) }
        #endif
    }

    #if os(iOS)
        private func updateDayPull(_ geometry: ScrollGeometry) {
            guard zoomGestureSession == nil else {
                dayPull.cancel()
                return
            }
            let metrics = ScheduleTimelineScrollMetrics(geometry: geometry)
            dayPull.update(
                offset: metrics.contentOffset.y,
                maximumOffset: metrics.maximumVerticalOffset,
                hasPreviousDay: previousDayLabel != nil, hasNextDay: nextDayLabel != nil)
        }

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
                if activeTouches.count == 1, let touch = activeTouches.first {
                    dayPull.moveTouch(to: touch.location.y)
                }
                return
            }

            dayPull.cancel()
            let touchPoints = activeTouches.map(\.location)
            guard
                let touchGeometry = ScheduleTimelineZoomTouchGeometry(
                    firstTouch: touchPoints[0],
                    secondTouch: touchPoints[1]
                )
            else { return }

            let gestureSession =
                zoomGestureSession
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
            guard
                zoomFrameScheduler.shouldApply(
                    update,
                    relativeTo: current
                )
            else {
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
                timelineFixedTop: 0,
                horizontalLayout: horizontalLayout,
                verticalLayout: dayLayout
            )
        }
    #endif
}

#if os(iOS)
    private struct ScheduleTimelineZoomGestureSession {
        let zoomSession: ScheduleTimelineZoomSession
        let initialTouchGeometry: ScheduleTimelineZoomTouchGeometry
    }

    struct ScheduleTimelineScrollMetrics: Equatable {
        let contentOffset: CGPoint
        let contentSize: CGSize
        let containerSize: CGSize

        var maximumVerticalOffset: CGFloat {
            // SwiftUI's containerSize already excludes its content insets.
            max(contentSize.height - containerSize.height, 0)
        }

        init(geometry: ScrollGeometry) {
            contentOffset = CGPoint(
                x: geometry.contentOffset.x + geometry.contentInsets.leading,
                y: geometry.contentOffset.y + geometry.contentInsets.top)
            contentSize = geometry.contentSize
            containerSize = geometry.containerSize
        }
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
    let stages: [ScheduleTimelineStagePresentation]
    let onToggleSaved: (Event) -> Void
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

            ForEach(stages) { column in
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                        .frame(
                            height: stageHeaderHeight
                                + firstEventPadding
                                + heightPerHour * 0.25
                        )

                    events(column.items)

                    Spacer()
                }
                .frame(width: columnWidth, alignment: .topLeading)
            }

            Spacer(minLength: 0)
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
            case .event(let presentation):
                let eventHeight = CGFloat(presentation.duration) / 60 * heightPerHour
                ScheduleTimelineEventCell(
                    width: columnWidth,
                    height: eventHeight - 2,
                    presentation: presentation,
                    onToggleSaved: { onToggleSaved(presentation.event) }
                )
                .padding(.vertical, 1)
            case .gap(let gap):
                let gapHeight =
                    CGFloat(gap.duration / (60 * 60))
                    * heightPerHour
                Spacer()
                    .frame(width: columnWidth, height: gapHeight)
            }
        }
    }
}

private struct ScheduleTimelineTimeColumn: View {
    let timeIntervals: [Date]
    let timeLabels: [String]
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
            .frame(maxHeight: .infinity, alignment: .top)
            .offset(x: -scrollState.horizontalOffset)
    }

    private func content(obscuredTime: Date?) -> some View {
        ZStack(alignment: .topLeading) {
            Color(.systemBackground)

            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: topPadding)

                ForEach(timeIntervals.indices, id: \.self) { index in
                    let time = timeIntervals[index]
                    Text(timeLabels[index])
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
        let overlapDistance = (currentTimeIndicatorLabelHeight + timelineTimeLabelHeight) / 2
        return distanceInPoints < overlapDistance
    }
}

private struct ScheduleTimelineViewportGrid: View {
    #if os(iOS)
        let scrollState: ScheduleTimelineScrollState
    #else
        @ObservedObject var scrollState: ScheduleTimelineScrollState
    #endif
    let rowCount: Int
    let width: CGFloat
    let height: CGFloat
    let heightPerHour: CGFloat
    var topFadeHeight: CGFloat? = nil

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rowCount, id: \.self) { _ in
                Rectangle()
                    .fill(Color.timelineSeparator)
                    .frame(height: timelineGridLineThickness)
                    .frame(height: heightPerHour * 0.5)
                    .padding(0)
            }
        }
        .frame(width: width, height: height, alignment: .top)
        .clipped()
        .mask {
            ScheduleTimelineSeparatorFade(
                topFadeHeight: topFadeHeight ?? min(-scrollState.topOverscroll, 32))
        }
        .offset(x: -scrollState.horizontalOffset)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ScheduleTimelineStageHeaders: View {
    let stages: [ScheduleTimelineStagePresentation]
    let columnWidth: CGFloat
    let timeWidth: CGFloat
    let stageHeaderHeight: CGFloat
    let columnSpacing: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemBackground)

            ScheduleTimelineStageSeparatorGrid(
                stageCount: stages.count,
                columnWidth: columnWidth,
                timeWidth: timeWidth,
                topPadding: 0,
                columnSpacing: columnSpacing,
                horizontalOffset: 0
            )
            .allowsHitTesting(false)

            HStack(alignment: .top, spacing: columnSpacing) {
                Spacer()
                    .frame(width: timeWidth)

                ForEach(stages) { column in
                    let stage = column.stage
                    NavigationLink(
                        value: AppNavigationRoute.stage(
                            id: stage.id,
                            highlightedEventId: nil
                        )
                    ) {
                        stageHeader(column)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if stage.hasLocation {
                            Button {
                                StageMapView.openInMaps(stage: stage)
                            } label: {
                                Text("schedule.context.open_in_maps")
                                Image(systemName: "map")
                            }
                        }
                    } preview: {
                        StagePreview(stage: stage)
                    }
                    .frame(width: columnWidth, height: stageHeaderHeight)
                    .transition(.opacity)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: stageHeaderHeight)
    }

    private func stageHeader(_ column: ScheduleTimelineStagePresentation) -> some View {
        VStack(alignment: .center, spacing: 5) {
            StageNumber(stage: column.stage, size: 18, font: .caption2.weight(.semibold))
                .monospacedDigit()

            Text(column.title)
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

private struct ScheduleTimelineStageSeparatorGrid: View {
    let stageCount: Int
    let columnWidth: CGFloat
    let timeWidth: CGFloat
    let topPadding: CGFloat
    let columnSpacing: CGFloat
    let horizontalOffset: CGFloat

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
                            + horizontalOffset,
                        y: topPadding + separatorHeight / 2
                    )
            }
        }
    }
}

private struct ScheduleTimelineDayGridFade: View {
    #if os(iOS)
        let scrollState: ScheduleTimelineScrollState
    #else
        @ObservedObject var scrollState: ScheduleTimelineScrollState
    #endif

    var body: some View {
        ScheduleTimelineSeparatorFade(topFadeHeight: min(-scrollState.topOverscroll, 32))
    }
}

private struct ScheduleTimelineSeparatorFade: View {
    let topFadeHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: topFadeHeight)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 32)
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
    #if os(iOS)
        let scrollState: ScheduleTimelineScrollState
    #else
        @ObservedObject var scrollState: ScheduleTimelineScrollState
    #endif
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
        .offset(x: -scrollState.horizontalOffset)
        .offset(y: verticalPosition)
        .allowsHitTesting(false)
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.calendar = FestivalDateUtilities.festivalCalendar
    formatter.timeZone = FestivalConfiguration.timeZone
    return formatter
}()
