#if os(iOS)
import SwiftUI
import Testing
@testable import Rudolstadt

@MainActor
struct FestivalMapZoomTests {
    @Test
    func zoomButtonsKeepTheVisibleMapCenter() {
        let controller = makeController()
        controller.update(content: .clear, contentSize: size, zoom: 2) { _ in }
        controller.scrollView.contentOffset = CGPoint(x: 240, y: 500)
        let before = visibleCenter(controller)

        controller.update(content: .clear, contentSize: size, zoom: 3) { _ in }

        let after = visibleCenter(controller)
        #expect(abs(before.x - after.x) < 0.01)
        #expect(abs(before.y - after.y) < 0.01)
        #expect(abs(controller.scrollView.zoomScale - 3) < 0.01)
    }

    @Test
    func updatingMarkersDoesNotResetZoomOrScrollPosition() {
        let controller = makeController()
        controller.update(content: .clear, contentSize: size, zoom: 2) { _ in }
        controller.scrollView.contentOffset = CGPoint(x: 240, y: 500)

        controller.update(content: .blue, contentSize: size, zoom: 2) { _ in }

        #expect(controller.scrollView.zoomScale == 2)
        #expect(controller.scrollView.contentOffset == CGPoint(x: 240, y: 500))
    }

    @Test
    func nativeZoomReportsItsScaleWithoutAFeedbackLoop() {
        let controller = makeController()
        var reportedScales: [CGFloat] = []
        controller.update(content: .clear, contentSize: size, zoom: 2) { reportedScales.append($0) }
        #expect(reportedScales.isEmpty)

        controller.scrollView.setZoomScale(2.5, animated: false)

        #expect(reportedScales.last == 2.5)
    }

    @Test
    func resizingPreservesTheRelativeMapCenter() {
        let controller = makeController()
        controller.update(content: .clear, contentSize: size, zoom: 2) { _ in }
        controller.scrollView.contentOffset = CGPoint(x: 240, y: 500)
        let before = visibleCenter(controller)

        controller.view.frame.size = CGSize(width: 480, height: 320)
        let newSize = CGSize(width: 600, height: 1200)
        controller.update(content: .clear, contentSize: newSize, zoom: 2) { _ in }

        let after = visibleCenter(controller)
        #expect(abs(before.x / size.width - after.x / newSize.width) < 0.001)
        #expect(abs(before.y / size.height - after.y / newSize.height) < 0.001)
    }

    private let size = CGSize(width: 400, height: 800)

    private func makeController() -> FestivalMapZoomController<Color> {
        let controller = FestivalMapZoomController(content: Color.clear)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        controller.update(content: .clear, contentSize: size, zoom: 1) { _ in }
        return controller
    }

    private func visibleCenter(_ controller: FestivalMapZoomController<Color>) -> CGPoint {
        let scrollView = controller.scrollView
        return CGPoint(x: scrollView.bounds.midX / scrollView.zoomScale,
                       y: scrollView.bounds.midY / scrollView.zoomScale)
    }
}
#endif
