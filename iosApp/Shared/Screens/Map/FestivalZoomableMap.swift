import SwiftUI

final class FestivalMapZoomState: ObservableObject {
    @Published var scale: CGFloat = 1
}

struct FestivalMapMarkerScale: ViewModifier {
    @ObservedObject var zoom: FestivalMapZoomState
    func body(content: Content) -> some View { content.scaleEffect(1 / zoom.scale) }
}

struct FestivalZoomableMap<Content: View> {
    let contentSize: CGSize
    @ObservedObject var zoom: FestivalMapZoomState
    let content: Content

    init(contentSize: CGSize, zoom: FestivalMapZoomState, @ViewBuilder content: () -> Content) {
        self.contentSize = contentSize
        self.zoom = zoom
        self.content = content()
    }
}

#if os(iOS)
    import UIKit

    extension FestivalZoomableMap: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> FestivalMapZoomController<Content> {
            FestivalMapZoomController(content: content)
        }

        func updateUIViewController(
            _ controller: FestivalMapZoomController<Content>, context: Context
        ) {
            controller.update(content: content, contentSize: contentSize, zoom: zoom.scale) {
                if zoom.scale != $0 { zoom.scale = $0 }
            }
        }
    }

    final class FestivalMapZoomController<Content: View>: UIViewController, UIScrollViewDelegate {
        let scrollView = UIScrollView()
        private let hostingController: UIHostingController<Content>
        private var pendingContent: Content?
        private var isUpdating = false
        private var onZoomChange: ((CGFloat) -> Void)?
        private var lastViewportSize: CGSize = .zero
        private var relativeCenter: CGPoint?

        init(content: Content) {
            hostingController = UIHostingController(rootView: content)
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { return nil }

        override func loadView() {
            view = scrollView
            scrollView.delegate = self
            scrollView.minimumZoomScale = 1
            scrollView.maximumZoomScale = 8
            scrollView.bouncesZoom = false
            scrollView.contentInsetAdjustmentBehavior = .never
            addChild(hostingController)
            hostingController.safeAreaRegions = []
            hostingController.view.backgroundColor = .clear
            scrollView.addSubview(hostingController.view)
            hostingController.didMove(toParent: self)
        }

        func update(
            content: Content, contentSize: CGSize, zoom: CGFloat,
            onZoomChange: @escaping (CGFloat) -> Void
        ) {
            loadViewIfNeeded()
            isUpdating = true
            defer {
                isUpdating = false
                rememberViewport()
            }
            self.onZoomChange = onZoomChange
            if scrollView.isZooming {
                pendingContent = content
            } else {
                hostingController.rootView = content
                pendingContent = nil
            }
            guard let hostedView = hostingController.view else { return }
            let oldSize = hostedView.bounds.size
            let center = hostedView.convert(
                CGPoint(x: scrollView.bounds.midX, y: scrollView.bounds.midY), from: scrollView)
            let newCenter: CGPoint
            if oldSize != contentSize {
                scrollView.setZoomScale(1, animated: false)
                hostedView.frame = CGRect(origin: .zero, size: contentSize)
                scrollView.contentSize = contentSize
                let relative = scrollView.bounds.size != lastViewportSize ? relativeCenter : nil
                newCenter =
                    oldSize.width > 0 && oldSize.height > 0
                    ? CGPoint(
                        x: (relative?.x ?? center.x / oldSize.width) * contentSize.width,
                        y: (relative?.y ?? center.y / oldSize.height) * contentSize.height)
                    : CGPoint(x: contentSize.width / 2, y: contentSize.height / 2)
            } else {
                newCenter = center
            }
            let scale = min(scrollView.maximumZoomScale, max(scrollView.minimumZoomScale, zoom))
            guard !scrollView.isZooming, abs(scrollView.zoomScale - scale) > 0.0001 else { return }
            guard scrollView.bounds.width > 0, scrollView.bounds.height > 0 else {
                scrollView.setZoomScale(scale, animated: false)
                return
            }
            let size = CGSize(
                width: scrollView.bounds.width / scale, height: scrollView.bounds.height / scale)
            scrollView.zoom(
                to: CGRect(
                    x: newCenter.x - size.width / 2, y: newCenter.y - size.height / 2,
                    width: size.width, height: size.height), animated: false)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { hostingController.view }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            if !isUpdating {
                rememberViewport()
                onZoomChange?(scrollView.zoomScale)
            }
        }

        func scrollViewDidEndZooming(
            _ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat
        ) {
            // Data changes during a pinch become visible without replacing the hosting root on each frame.
            if let pendingContent {
                hostingController.rootView = pendingContent
                self.pendingContent = nil
            }
            if !isUpdating { onZoomChange?(scale) }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !isUpdating, scrollView.bounds.size == lastViewportSize { rememberViewport() }
        }

        private func rememberViewport() {
            guard let hostedView = hostingController.viewIfLoaded,
                hostedView.bounds.width > 0, hostedView.bounds.height > 0,
                scrollView.bounds.width > 0, scrollView.bounds.height > 0
            else { return }
            let center = hostedView.convert(
                CGPoint(x: scrollView.bounds.midX, y: scrollView.bounds.midY), from: scrollView)
            relativeCenter = CGPoint(
                x: center.x / hostedView.bounds.width, y: center.y / hostedView.bounds.height)
            lastViewportSize = scrollView.bounds.size
        }
    }
#else
    import AppKit

    extension FestivalZoomableMap: NSViewRepresentable {
        func makeNSView(context: Context) -> FestivalMapZoomScrollView<Content> {
            FestivalMapZoomScrollView(content: content)
        }

        func updateNSView(_ view: FestivalMapZoomScrollView<Content>, context: Context) {
            view.update(content: content, contentSize: contentSize, zoom: zoom.scale) {
                if zoom.scale != $0 { zoom.scale = $0 }
            }
        }
    }

    final class FestivalMapZoomScrollView<Content: View>: NSScrollView {
        private let hostingView: NSHostingView<Content>
        private var onZoomChange: ((CGFloat) -> Void)?

        init(content: Content) {
            hostingView = NSHostingView(rootView: content)
            super.init(frame: .zero)
            documentView = hostingView
            drawsBackground = false
            hasVerticalScroller = true
            hasHorizontalScroller = true
            autohidesScrollers = true
            allowsMagnification = true
            minMagnification = 1
            maxMagnification = 8
        }

        required init?(coder: NSCoder) { return nil }

        func update(
            content: Content, contentSize: CGSize, zoom: CGFloat,
            onZoomChange: @escaping (CGFloat) -> Void
        ) {
            self.onZoomChange = onZoomChange
            hostingView.rootView = content
            hostingView.setFrameSize(contentSize)
            let scale = min(maxMagnification, max(minMagnification, zoom))
            if abs(magnification - scale) > 0.0001 {
                setMagnification(
                    scale,
                    centeredAt: CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY))
            }
        }

        override func magnify(with event: NSEvent) {
            super.magnify(with: event)
            onZoomChange?(magnification)
        }

        override func smartMagnify(with event: NSEvent) {
            super.smartMagnify(with: event)
            onZoomChange?(magnification)
        }
    }
#endif
