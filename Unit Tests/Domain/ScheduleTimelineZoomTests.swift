import CoreGraphics
import Testing
@testable import Rudolstadt

struct ScheduleTimelineZoomTests {
    @Test
    func zoomKeepsAnchorAtSameViewportPosition() {
        let session = ScheduleTimelineZoomSession(
            baseHeightPerHour: 60,
            contentOffset: CGPoint(x: 120, y: 300),
            contentSize: CGSize(width: 1_000, height: 1_200),
            containerSize: CGSize(width: 390, height: 700),
            anchorViewportPoint: CGPoint(x: 100, y: 250),
            timelineFixedTop: 65
        )

        let update = session.update(
            for: 1.5,
            anchorViewportPoint: CGPoint(x: 100, y: 250)
        )

        #expect(update.heightPerHour == 90)
        #expect(update.contentOffset.x == 120)
        #expect(abs(update.contentOffset.y - 542.5) < 0.001)
    }

    @Test
    func zoomTracksMovingTouchCentroidAsScrolling() {
        let session = ScheduleTimelineZoomSession(
            baseHeightPerHour: 60,
            contentOffset: CGPoint(x: 120, y: 300),
            contentSize: CGSize(width: 1_000, height: 1_200),
            containerSize: CGSize(width: 390, height: 700),
            anchorViewportPoint: CGPoint(x: 100, y: 250),
            timelineFixedTop: 65
        )

        let update = session.update(
            for: 1.5,
            anchorViewportPoint: CGPoint(x: 80, y: 220)
        )

        #expect(update.contentOffset.x == 140)
        #expect(abs(update.contentOffset.y - 572.5) < 0.001)
    }

    @Test
    func twoFingerScrollingClampsAtHorizontalEdge() {
        let session = ScheduleTimelineZoomSession(
            baseHeightPerHour: 60,
            contentOffset: CGPoint(x: 600, y: 300),
            contentSize: CGSize(width: 1_000, height: 1_200),
            containerSize: CGSize(width: 390, height: 700),
            anchorViewportPoint: CGPoint(x: 100, y: 250),
            timelineFixedTop: 65
        )

        let update = session.update(
            for: 1,
            anchorViewportPoint: CGPoint(x: 50, y: 250)
        )

        #expect(update.contentOffset.x == 610)
    }

    @Test
    func zoomLimitsVerticalScale() {
        let session = makeSession()
        let anchorViewportPoint = CGPoint(x: 100, y: 250)

        #expect(
            session.update(
                for: 0.1,
                anchorViewportPoint: anchorViewportPoint
            ).heightPerHour
                == ScheduleTimelineZoom.minimumHeightPerHour
        )
        #expect(
            session.update(
                for: 3,
                anchorViewportPoint: anchorViewportPoint
            ).heightPerHour
                == ScheduleTimelineZoom.maximumHeightPerHour
        )
    }

    @Test
    func zoomClampsOffsetAtTopEdge() {
        let session = makeSession(
            contentOffset: CGPoint(x: 40, y: 0),
            anchorViewportY: 100
        )

        let update = session.update(
            for: 0.5,
            anchorViewportPoint: CGPoint(x: 100, y: 100)
        )

        #expect(update.contentOffset == CGPoint(x: 40, y: 0))
    }

    @Test
    func zoomClampsOffsetAtBottomEdge() {
        let session = makeSession(
            contentOffset: CGPoint(x: 40, y: 500),
            anchorViewportY: 600
        )

        let update = session.update(
            for: 0.7,
            anchorViewportPoint: CGPoint(x: 100, y: 600)
        )

        #expect(update.contentOffset.x == 40)
        #expect(abs(update.contentOffset.y - 159.5) < 0.001)
    }

    @Test
    func zoomUpdateIgnoresSubpixelChanges() {
        let reference = ScheduleTimelineZoomUpdate(
            heightPerHour: 60,
            contentOffset: CGPoint(x: 20, y: 200)
        )
        let update = ScheduleTimelineZoomUpdate(
            heightPerHour: 60.1,
            contentOffset: CGPoint(x: 20.1, y: 200.4)
        )

        #expect(!update.isMeaningfullyDifferent(from: reference))
    }

    @Test
    func zoomUpdateAcceptsVisibleScaleOrOffsetChanges() {
        let reference = ScheduleTimelineZoomUpdate(
            heightPerHour: 60,
            contentOffset: CGPoint(x: 20, y: 200)
        )
        let scaleUpdate = ScheduleTimelineZoomUpdate(
            heightPerHour: 60.25,
            contentOffset: reference.contentOffset
        )
        let offsetUpdate = ScheduleTimelineZoomUpdate(
            heightPerHour: reference.heightPerHour,
            contentOffset: CGPoint(x: 20, y: 200.5)
        )

        #expect(scaleUpdate.isMeaningfullyDifferent(from: reference))
        #expect(offsetUpdate.isMeaningfullyDifferent(from: reference))
    }

    private func makeSession(
        contentOffset: CGPoint = CGPoint(x: 120, y: 300),
        anchorViewportY: CGFloat = 250
    ) -> ScheduleTimelineZoomSession {
        ScheduleTimelineZoomSession(
            baseHeightPerHour: 60,
            contentOffset: contentOffset,
            contentSize: CGSize(width: 1_000, height: 1_200),
            containerSize: CGSize(width: 390, height: 700),
            anchorViewportPoint: CGPoint(x: 100, y: anchorViewportY),
            timelineFixedTop: 65
        )
    }
}
