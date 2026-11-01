import PDFKit
import SwiftUI

/// PDFKit keeps the original vector plan zoomable and available offline.
final class FestivalPlanPDFView: PDFView {
    var pendingPageIndex = 0
    private var highlightedPageIndex: Int?
    var pendingPoint: FestivalPlanPoint?
    private var highlightedPoint: FestivalPlanPoint?
    private var marker: PDFAnnotation?

    #if os(iOS)
    override func layoutSubviews() {
        super.layoutSubviews()
        focusOnPendingPoint()
    }

    #else
    override func layout() {
        super.layout()
        focusOnPendingPoint()
    }
    #endif

    private func focusOnPendingPoint() {
        guard bounds.width > 0, bounds.height > 0,
              let point = pendingPoint, (point != highlightedPoint || pendingPageIndex != highlightedPageIndex),
              let page = document?.page(at: pendingPageIndex) else { return }
        pendingPoint = nil
        if let marker, let oldPageIndex = highlightedPageIndex {
            document?.page(at: oldPageIndex)?.removeAnnotation(marker)
        }
        highlightedPoint = point
        highlightedPageIndex = pendingPageIndex
        let pageBounds = page.bounds(for: .mediaBox)
        let center = CGPoint(x: pageBounds.minX + pageBounds.width * point.x,
                             y: pageBounds.maxY - pageBounds.height * point.y)
        let annotation = PDFAnnotation(
            bounds: CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24),
            forType: .circle, withProperties: nil
        )
        annotation.color = .orange
        let border = PDFBorder()
        border.lineWidth = 3
        annotation.border = border
        page.addAnnotation(annotation)
        marker = annotation
        autoScales = false
        scaleFactor = min(maxScaleFactor, max(scaleFactorForSizeToFit, bounds.width / 190))
        // Use page coordinates directly; the illustrated plan is not georeferenced.
        go(to: CGRect(x: center.x - 95, y: center.y - 95, width: 190, height: 190), on: page)
    }
}

#if os(iOS)
struct FestivalPlanDocumentView: UIViewRepresentable {
    let document: PDFDocument
    let point: FestivalPlanPoint?
    var pageIndex = 0

    func makeUIView(context: Context) -> FestivalPlanPDFView {
        let view = FestivalPlanPDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePage
        view.pendingPageIndex = pageIndex
        view.pendingPoint = point
        return view
    }

    func updateUIView(_ view: FestivalPlanPDFView, context: Context) {
        view.pendingPageIndex = pageIndex
        view.pendingPoint = point
        view.setNeedsLayout()
    }
}
#else
struct FestivalPlanDocumentView: NSViewRepresentable {
    let document: PDFDocument
    let point: FestivalPlanPoint?
    var pageIndex = 0

    func makeNSView(context: Context) -> FestivalPlanPDFView {
        let view = FestivalPlanPDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePage
        view.pendingPageIndex = pageIndex
        view.pendingPoint = point
        return view
    }

    func updateNSView(_ view: FestivalPlanPDFView, context: Context) {
        view.pendingPageIndex = pageIndex
        view.pendingPoint = point
        view.needsLayout = true
    }
}
#endif
