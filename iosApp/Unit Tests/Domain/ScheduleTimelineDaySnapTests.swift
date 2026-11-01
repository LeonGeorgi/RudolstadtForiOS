import CoreGraphics
import SwiftUI
import Testing

@testable import Rudolstadt

struct ScheduleTimelineDaySnapTests {
    @Test(arguments: [619.0, 1200])
    func systemInsetsDoNotDelayTheBottomPull(contentHeight: Double) {
        // Measured on iPhone: the native viewport is 619 points beneath 116/139-point insets.
        let insets = EdgeInsets(top: 116, leading: 0, bottom: 139, trailing: 0)
        func metrics(rawOffset: CGFloat) -> ScheduleTimelineScrollMetrics {
            ScheduleTimelineScrollMetrics(
                geometry: ScrollGeometry(
                    contentOffset: CGPoint(x: 0, y: rawOffset),
                    contentSize: CGSize(width: 435, height: contentHeight),
                    contentInsets: insets, containerSize: CGSize(width: 402, height: 619)))
        }
        let first = metrics(rawOffset: -116)
        let last = metrics(rawOffset: CGFloat(contentHeight) - 619 - 116)
        #expect(first.contentOffset.y == 0)
        #expect(last.contentOffset.y == last.maximumVerticalOffset)
        #expect(last.maximumVerticalOffset == CGFloat(contentHeight) - 619)

        for atTop in [true, false] {
            let edge = metrics(rawOffset: atTop ? -121 : CGFloat(contentHeight) - 619 - 111)
            var pull = ScheduleTimelineDayPull()
            pull.moveTouch(to: 300)
            pull.begin()
            pull.update(
                offset: edge.contentOffset.y, maximumOffset: edge.maximumVerticalOffset,
                hasPreviousDay: true, hasNextDay: true)
            pull.moveTouch(to: atTop ? 412.5 : 187.5)
            #expect(pull.hint?.progress == 0)
            #expect(pull.hint?.opacity ?? 0 > 0)
            #expect(pull.hint?.isReady != true)
        }
    }

    private func pull(atTop: Bool, distance: CGFloat) -> ScheduleTimelineDayPull {
        var pull = ScheduleTimelineDayPull()
        pull.moveTouch(to: 300)
        pull.begin()
        pull.update(
            offset: atTop ? -1 : 501, maximumOffset: 500,
            hasPreviousDay: true, hasNextDay: true)
        pull.moveTouch(to: 300 + (atTop ? distance : -distance))
        return pull
    }

    @Test(arguments: [0.0, 20, 50, 60, 299, 300, 340])
    func bothEdgesRequireExactlyTheSameFingerTravel(distance: Double) {
        var top = pull(atTop: true, distance: CGFloat(distance))
        var bottom = pull(atTop: false, distance: CGFloat(distance))
        #expect(top.hint?.isReady == bottom.hint?.isReady)
        #expect(top.end() == (distance >= 300 ? .previous : nil))
        #expect(bottom.end() == (distance >= 300 ? .next : nil))
    }

    @Test
    func contentBounceDistanceDoesNotDetermineReadiness() {
        var top = pull(atTop: true, distance: 100)
        var bottom = pull(atTop: false, distance: 100)
        top.update(offset: -100, maximumOffset: 500, hasPreviousDay: true, hasNextDay: true)
        bottom.update(offset: 530, maximumOffset: 500, hasPreviousDay: true, hasNextDay: true)
        #expect(top.hint?.isReady == false)
        #expect(bottom.hint?.isReady == false)
        top.moveTouch(to: 600)
        bottom.moveTouch(to: 0)
        #expect(top.end() == .previous)
        #expect(bottom.end() == .next)
    }

    @Test
    func normalScrollingBeforeTheEdgeDoesNotCountAsPulling() {
        var pull = ScheduleTimelineDayPull()
        pull.moveTouch(to: 600)
        pull.begin()
        pull.update(offset: 300, maximumOffset: 500, hasPreviousDay: true, hasNextDay: true)
        pull.moveTouch(to: 200)
        pull.update(offset: 501, maximumOffset: 500, hasPreviousDay: true, hasNextDay: true)
        pull.moveTouch(to: 100)
        #expect(pull.hint?.isReady == false)
        pull.moveTouch(to: -100)
        #expect(pull.end() == .next)
    }

    @Test
    func decelerationCannotSwitchDaysEvenWhenItBouncesPastTheThreshold() {
        var pull = pull(atTop: false, distance: 60)
        #expect(pull.end() == nil)
        pull.update(offset: 650, maximumOffset: 500, hasPreviousDay: true, hasNextDay: true)
        pull.moveTouch(to: 0)
        #expect(pull.hint == nil)
        #expect(pull.end() == nil)
    }

    @Test
    func reversingThePullDisarmsTheDayChange() {
        var pull = pull(atTop: false, distance: 340)
        #expect(pull.hint?.isReady == true)
        pull.moveTouch(to: 240)
        #expect(pull.hint?.isReady == false)
        #expect(pull.end() == nil)
    }

    @Test
    func returningInsideTheDayResetsThePullOrigin() {
        var pull = pull(atTop: true, distance: 340)
        pull.update(offset: 10, maximumOffset: 500, hasPreviousDay: true, hasNextDay: true)
        #expect(pull.hint == nil)
        pull.moveTouch(to: 300)
        pull.update(offset: -1, maximumOffset: 500, hasPreviousDay: true, hasNextDay: true)
        pull.moveTouch(to: 400)
        #expect(pull.hint?.isReady == false)
        #expect(pull.end() == nil)
    }

    @Test
    func firstAndLastDayKeepTheirNativeBounceWithoutChangingDays() {
        for atTop in [true, false] {
            var pull = ScheduleTimelineDayPull()
            pull.moveTouch(to: 300)
            pull.begin()
            pull.update(
                offset: atTop ? -100 : 600, maximumOffset: 500,
                hasPreviousDay: !atTop, hasNextDay: atTop)
            pull.moveTouch(to: atTop ? 500 : 100)
            #expect(pull.hint == nil)
            #expect(pull.end() == nil)
        }
    }

    @Test
    func cancelingForZoomOrDisappearanceCannotChangeTheDay() {
        var pull = pull(atTop: false, distance: 340)
        pull.cancel()
        #expect(pull.end() == nil)
    }

    @Test
    func fadingFinishesBeforeProgressAndHapticsBegin() {
        for atTop in [true, false] {
            var pull = pull(atTop: atTop, distance: 50)
            #expect(pull.hint == nil)
            for step in 1...4 {
                let distance = 50 + CGFloat(step) * 27.5
                pull.moveTouch(to: 300 + (atTop ? distance : -distance))
                #expect(pull.hint?.opacity == CGFloat(step) / 4)
                #expect(pull.hint?.progress == 0)
                #expect(pull.hint?.isReady != true)
            }
            pull.moveTouch(to: atTop ? 530 : 70)
            #expect(pull.hint?.opacity == 1)
            #expect(pull.hint?.progress == 0.5)
            // Reversing restores the fade phase without retaining progress.
            pull.moveTouch(to: atTop ? 405 : 195)
            #expect(pull.hint?.opacity == 0.5)
            #expect(pull.hint?.progress == 0)
            #expect(pull.hint?.isReady != true)
        }
    }

    @Test
    func readinessRemainsFalseUntilTheCircleIsFull() {
        for atTop in [true, false] {
            var pull = pull(atTop: atTop, distance: 50)
            for distance: CGFloat in [60, 160, 206, 254, 299, 300, 340] {
                pull.moveTouch(to: 300 + (atTop ? distance : -distance))
                #expect(pull.hint?.isReady == (distance >= 300))
            }
            #expect(pull.hint?.progress == 1)
        }
    }

    @Test
    func retreatingDisarmsReadinessUntilTheCircleIsFullAgain() {
        var pull = pull(atTop: true, distance: 340)
        #expect(pull.hint?.isReady == true)
        pull.moveTouch(to: 580)
        #expect(pull.hint?.isReady == false)
        pull.moveTouch(to: 599)
        #expect(pull.hint?.isReady == false)
        pull.moveTouch(to: 600)
        #expect(pull.hint?.isReady == true)
        pull.moveTouch(to: 620)
        #expect(pull.hint?.isReady == true)
        pull.cancel()
        #expect(pull.hint == nil)
    }

    @Test
    func shortDayFillsTheViewportAtEveryZoomLevel() {
        let layout = ScheduleTimelineDayLayout(hours: 2, headerHeight: 60, viewportHeight: 600)
        for scale: CGFloat in [42, 60, 120] {
            #expect(layout.contentHeight(heightPerHour: scale) == 600)
        }
    }

    @Test
    func zoomPreservesFixedHeadingsAndScalesConcertTime() {
        let layout = ScheduleTimelineDayLayout(hours: 10, headerHeight: 60, viewportHeight: 600)
        #expect(layout.rescaledY(60, from: 60, to: 120) == 60)
        #expect(layout.rescaledY(180, from: 60, to: 120) == 300)
        #expect(layout.contentHeight(heightPerHour: 120) == 1260)
    }

    @Test
    func zoomDoesNotTreatPaddingAsConcertTime() {
        let layout = ScheduleTimelineDayLayout(hours: 2, headerHeight: 60, viewportHeight: 600)
        #expect(layout.rescaledY(280, from: 60, to: 120) == 400)
        #expect(layout.rescaledY(590, from: 60, to: 120) == 600)
    }
}
