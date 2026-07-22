import CoreGraphics
#if os(iOS)
import Foundation
import QuartzCore
#endif

enum ScheduleTimelineZoom {
    static let defaultHeightPerHour: CGFloat = 60
    static let minimumHeightPerHour: CGFloat = 42
    static let maximumHeightPerHour: CGFloat = 120
    static let defaultColumnWidth: CGFloat = 70
    static let minimumColumnWidth: CGFloat = 48
    static let maximumColumnWidth: CGFloat = 140
    static let minimumHeightChange: CGFloat = 0.25
    static let minimumColumnWidthChange: CGFloat = 0.25
    static let minimumContentOffsetChange: CGFloat = 0.5
    static let minimumScaleReferenceDistance: CGFloat = 44
}

struct ScheduleTimelineZoomMagnification: Equatable {
    let horizontal: CGFloat
    let vertical: CGFloat

    init(horizontal: CGFloat = 1, vertical: CGFloat = 1) {
        self.horizontal = horizontal
        self.vertical = vertical
    }
}

struct ScheduleTimelineZoomTouchGeometry: Equatable {
    let centroid: CGPoint
    let horizontalSpan: CGFloat
    let verticalSpan: CGFloat
    let distance: CGFloat

    init?(firstTouch: CGPoint, secondTouch: CGPoint) {
        let horizontalDifference = secondTouch.x - firstTouch.x
        let verticalDifference = secondTouch.y - firstTouch.y
        let distance = hypot(horizontalDifference, verticalDifference)
        guard distance > 0 else { return nil }

        self.centroid = CGPoint(
            x: (firstTouch.x + secondTouch.x) / 2,
            y: (firstTouch.y + secondTouch.y) / 2
        )
        self.horizontalSpan = abs(horizontalDifference)
        self.verticalSpan = abs(verticalDifference)
        self.distance = distance
    }

    func magnification(
        relativeTo initial: ScheduleTimelineZoomTouchGeometry
    ) -> ScheduleTimelineZoomMagnification {
        let referenceDistance = max(
            initial.distance,
            ScheduleTimelineZoom.minimumScaleReferenceDistance
        )

        return ScheduleTimelineZoomMagnification(
            horizontal: max(
                1 + (horizontalSpan - initial.horizontalSpan)
                    / referenceDistance,
                0
            ),
            vertical: max(
                1 + (verticalSpan - initial.verticalSpan)
                    / referenceDistance,
                0
            )
        )
    }
}

struct ScheduleTimelineHorizontalLayout {
    let stageCount: Int
    let timeWidth: CGFloat
    let columnSpacing: CGFloat

    func contentWidth(
        columnWidth: CGFloat,
        minimumWidth: CGFloat
    ) -> CGFloat {
        let naturalWidth = timeWidth
            + CGFloat(stageCount) * columnWidth
            + CGFloat(stageCount + 1) * columnSpacing
        return max(naturalWidth, minimumWidth)
    }

    func rescaledContentX(
        _ contentX: CGFloat,
        from baseColumnWidth: CGFloat,
        to columnWidth: CGFloat
    ) -> CGFloat {
        guard stageCount > 0 else { return contentX }

        let firstStageX = timeWidth + columnSpacing
        guard contentX > firstStageX else { return contentX }

        let basePitch = baseColumnWidth + columnSpacing
        let relativeX = contentX - firstStageX
        let completedColumns = min(
            max(Int(relativeX / basePitch), 0),
            stageCount
        )
        let localX = relativeX - CGFloat(completedColumns) * basePitch
        let localColumnProgress = completedColumns < stageCount
            ? min(max(localX / baseColumnWidth, 0), 1)
            : 0
        let columnWidthChange = columnWidth - baseColumnWidth

        return contentX
            + (CGFloat(completedColumns) + localColumnProgress)
                * columnWidthChange
    }
}

struct ScheduleTimelineZoomUpdate: Equatable {
    let heightPerHour: CGFloat
    let columnWidth: CGFloat
    let contentOffset: CGPoint

    func isMeaningfullyDifferent(
        from other: ScheduleTimelineZoomUpdate
    ) -> Bool {
        abs(heightPerHour - other.heightPerHour)
            >= ScheduleTimelineZoom.minimumHeightChange
            || abs(columnWidth - other.columnWidth)
                >= ScheduleTimelineZoom.minimumColumnWidthChange
            || abs(contentOffset.x - other.contentOffset.x)
                >= ScheduleTimelineZoom.minimumContentOffsetChange
            || abs(contentOffset.y - other.contentOffset.y)
                >= ScheduleTimelineZoom.minimumContentOffsetChange
    }
}

struct ScheduleTimelineZoomSession {
    let baseHeightPerHour: CGFloat
    let baseColumnWidth: CGFloat
    let anchorHoursFromTimelineTop: CGFloat
    let anchorBaseContentX: CGFloat
    let baseContentSize: CGSize
    let containerSize: CGSize
    let timelineFixedTop: CGFloat
    let horizontalLayout: ScheduleTimelineHorizontalLayout
    let horizontalContentExtraWidth: CGFloat

    init(
        baseHeightPerHour: CGFloat,
        baseColumnWidth: CGFloat,
        contentOffset: CGPoint,
        contentSize: CGSize,
        containerSize: CGSize,
        anchorViewportPoint: CGPoint,
        timelineFixedTop: CGFloat,
        horizontalLayout: ScheduleTimelineHorizontalLayout
    ) {
        self.baseHeightPerHour = baseHeightPerHour
        self.baseColumnWidth = baseColumnWidth
        self.anchorBaseContentX = contentOffset.x + anchorViewportPoint.x
        self.baseContentSize = contentSize
        self.containerSize = containerSize
        self.timelineFixedTop = timelineFixedTop
        self.horizontalLayout = horizontalLayout
        self.horizontalContentExtraWidth = max(
            contentSize.width - horizontalLayout.contentWidth(
                columnWidth: baseColumnWidth,
                minimumWidth: containerSize.width
            ),
            0
        )
        self.anchorHoursFromTimelineTop = (
            contentOffset.y + anchorViewportPoint.y - timelineFixedTop
        ) / baseHeightPerHour
    }

    func update(
        for magnification: ScheduleTimelineZoomMagnification,
        anchorViewportPoint: CGPoint
    ) -> ScheduleTimelineZoomUpdate {
        let heightPerHour = min(
            max(
                baseHeightPerHour * magnification.vertical,
                ScheduleTimelineZoom.minimumHeightPerHour
            ),
            ScheduleTimelineZoom.maximumHeightPerHour
        )
        let columnWidth = min(
            max(
                baseColumnWidth * magnification.horizontal,
                ScheduleTimelineZoom.minimumColumnWidth
            ),
            ScheduleTimelineZoom.maximumColumnWidth
        )
        let verticalScale = heightPerHour / baseHeightPerHour
        let scalableContentHeight = max(
            baseContentSize.height - timelineFixedTop,
            0
        )
        let contentHeight = timelineFixedTop
            + scalableContentHeight * verticalScale
        let contentWidth = horizontalLayout.contentWidth(
            columnWidth: columnWidth,
            minimumWidth: containerSize.width
        ) + horizontalContentExtraWidth
        let maximumHorizontalOffset = max(
            contentWidth - containerSize.width,
            0
        )
        let maximumVerticalOffset = max(
            contentHeight - containerSize.height,
            0
        )
        let anchorContentX = horizontalLayout.rescaledContentX(
            anchorBaseContentX,
            from: baseColumnWidth,
            to: columnWidth
        )
        let proposedHorizontalOffset = anchorContentX - anchorViewportPoint.x
        let proposedVerticalOffset = timelineFixedTop
            + anchorHoursFromTimelineTop * heightPerHour
            - anchorViewportPoint.y
        let horizontalOffset = min(
            max(proposedHorizontalOffset, 0),
            maximumHorizontalOffset
        )
        let verticalOffset = min(
            max(proposedVerticalOffset, 0),
            maximumVerticalOffset
        )

        return ScheduleTimelineZoomUpdate(
            heightPerHour: heightPerHour,
            columnWidth: columnWidth,
            contentOffset: CGPoint(
                x: horizontalOffset,
                y: verticalOffset
            )
        )
    }
}

#if os(iOS)
@MainActor
final class ScheduleTimelineZoomFrameScheduler {
    private var displayLink: CADisplayLink?
    private var pendingUpdate: (() -> Void)?
    private var completionAfterNextFrame: (() -> Void)?
    private var lastAppliedUpdate: ScheduleTimelineZoomUpdate?
    private lazy var target = DisplayLinkTarget(scheduler: self)

    func submit(_ update: @escaping () -> Void) {
        pendingUpdate = update
        startIfNeeded()
    }

    func finish(afterNextFrame completion: @escaping () -> Void) {
        completionAfterNextFrame = completion
        startIfNeeded()
    }

    func shouldApply(
        _ update: ScheduleTimelineZoomUpdate,
        relativeTo current: ScheduleTimelineZoomUpdate
    ) -> Bool {
        let reference = lastAppliedUpdate ?? current
        guard update != reference else { return false }
        guard update.isMeaningfullyDifferent(from: reference) else {
            return false
        }

        lastAppliedUpdate = update
        return true
    }

    func cancel() {
        pendingUpdate = nil
        completionAfterNextFrame = nil
        lastAppliedUpdate = nil
        stop()
    }

    fileprivate func displayLinkDidFire() {
        let update = pendingUpdate
        pendingUpdate = nil
        update?()

        if let completion = completionAfterNextFrame {
            completionAfterNextFrame = nil
            lastAppliedUpdate = nil
            stop()
            completion()
        }
    }

    private func startIfNeeded() {
        guard displayLink == nil else { return }

        let displayLink = CADisplayLink(
            target: target,
            selector: #selector(DisplayLinkTarget.displayLinkDidFire(_:))
        )
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    private func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }
}

@MainActor
private final class DisplayLinkTarget: NSObject {
    private weak var scheduler: ScheduleTimelineZoomFrameScheduler?

    init(scheduler: ScheduleTimelineZoomFrameScheduler) {
        self.scheduler = scheduler
    }

    @objc
    func displayLinkDidFire(_ displayLink: CADisplayLink) {
        guard let scheduler else {
            displayLink.invalidate()
            return
        }

        scheduler.displayLinkDidFire()
    }
}
#endif
