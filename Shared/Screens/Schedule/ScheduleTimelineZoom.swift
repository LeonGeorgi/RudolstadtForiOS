import CoreGraphics
#if os(iOS)
import Foundation
import QuartzCore
#endif

enum ScheduleTimelineZoom {
    static let defaultHeightPerHour: CGFloat = 60
    static let minimumHeightPerHour: CGFloat = 42
    static let maximumHeightPerHour: CGFloat = 120
    static let minimumHeightChange: CGFloat = 0.25
    static let minimumContentOffsetChange: CGFloat = 0.5
}

struct ScheduleTimelineZoomUpdate: Equatable {
    let heightPerHour: CGFloat
    let contentOffset: CGPoint

    func isMeaningfullyDifferent(
        from other: ScheduleTimelineZoomUpdate
    ) -> Bool {
        abs(heightPerHour - other.heightPerHour)
            >= ScheduleTimelineZoom.minimumHeightChange
            || abs(contentOffset.x - other.contentOffset.x)
                >= ScheduleTimelineZoom.minimumContentOffsetChange
            || abs(contentOffset.y - other.contentOffset.y)
                >= ScheduleTimelineZoom.minimumContentOffsetChange
    }
}

struct ScheduleTimelineZoomSession {
    let baseHeightPerHour: CGFloat
    let anchorHoursFromTimelineTop: CGFloat
    let anchorContentX: CGFloat
    let baseContentSize: CGSize
    let containerSize: CGSize
    let timelineFixedTop: CGFloat

    init(
        baseHeightPerHour: CGFloat,
        contentOffset: CGPoint,
        contentSize: CGSize,
        containerSize: CGSize,
        anchorViewportPoint: CGPoint,
        timelineFixedTop: CGFloat
    ) {
        self.baseHeightPerHour = baseHeightPerHour
        self.anchorContentX = contentOffset.x + anchorViewportPoint.x
        self.baseContentSize = contentSize
        self.containerSize = containerSize
        self.timelineFixedTop = timelineFixedTop
        self.anchorHoursFromTimelineTop = (
            contentOffset.y + anchorViewportPoint.y - timelineFixedTop
        ) / baseHeightPerHour
    }

    func update(
        for magnification: CGFloat,
        anchorViewportPoint: CGPoint
    ) -> ScheduleTimelineZoomUpdate {
        let heightPerHour = min(
            max(
                baseHeightPerHour * magnification,
                ScheduleTimelineZoom.minimumHeightPerHour
            ),
            ScheduleTimelineZoom.maximumHeightPerHour
        )
        let scale = heightPerHour / baseHeightPerHour
        let scalableContentHeight = max(
            baseContentSize.height - timelineFixedTop,
            0
        )
        let contentHeight = timelineFixedTop + scalableContentHeight * scale
        let maximumHorizontalOffset = max(
            baseContentSize.width - containerSize.width,
            0
        )
        let maximumVerticalOffset = max(
            contentHeight - containerSize.height,
            0
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
