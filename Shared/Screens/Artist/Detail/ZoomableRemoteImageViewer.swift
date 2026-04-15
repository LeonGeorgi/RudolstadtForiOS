import SDWebImage
import SwiftUI

struct ZoomableRemoteImageViewer: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZoomableImageScrollView(url: url)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .padding(.top, 18)
            .padding(.trailing, 18)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct ZoomableImageScrollView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .black
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.sd_setImage(with: url) { _, _, _, _ in
            DispatchQueue.main.async {
                context.coordinator.updateLayout(in: scrollView)
            }
        }

        let doubleTapRecognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTapRecognizer.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTapRecognizer)

        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        if context.coordinator.imageView?.sd_imageURL != url {
            scrollView.zoomScale = 1
            context.coordinator.imageView?.sd_setImage(with: url) { _, _, _, _ in
                DispatchQueue.main.async {
                    context.coordinator.updateLayout(in: scrollView)
                }
            }
        }

        context.coordinator.updateLayout(in: scrollView)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            updateInsets(in: scrollView)
        }

        func updateLayout(in scrollView: UIScrollView) {
            guard let imageView else { return }

            imageView.frame = CGRect(origin: .zero, size: scrollView.bounds.size)
            scrollView.contentSize = imageView.bounds.size
            updateInsets(in: scrollView)
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let location = recognizer.location(in: imageView)
                let targetScale = min(scrollView.maximumZoomScale, 2.5)
                let zoomSize = CGSize(
                    width: scrollView.bounds.width / targetScale,
                    height: scrollView.bounds.height / targetScale
                )
                let zoomRect = CGRect(
                    x: location.x - zoomSize.width / 2,
                    y: location.y - zoomSize.height / 2,
                    width: zoomSize.width,
                    height: zoomSize.height
                )
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }

        private func updateInsets(in scrollView: UIScrollView) {
            guard let imageView else { return }

            let horizontalInset = max((scrollView.bounds.width - imageView.frame.width) / 2, 0)
            let verticalInset = max((scrollView.bounds.height - imageView.frame.height) / 2, 0)
            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }
    }
}
