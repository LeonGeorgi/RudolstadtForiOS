import NukeUI
import SwiftUI
#if os(iOS)
import LazyPager
#endif

struct ZoomableRemoteImageViewer: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var backgroundOpacity: CGFloat = 1
    @State private var controlsVisible = true
    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            pagerContent
                .ignoresSafeArea()

            if controlsVisible {
                closeButton
                    .padding(.trailing, 18)
            }
        }
        .background(Color.black.opacity(backgroundOpacity).ignoresSafeArea())
#if os(iOS)
        .background(ClearFullScreenBackground())
#endif
    }

    @ViewBuilder
    private var pagerContent: some View {
#if os(iOS)
        LazyPager(data: [url], page: $currentPage) { pageURL in
            remoteImage(for: pageURL)
        }
        .zoomable(min: 1, max: 5)
        .onDismiss(backgroundOpacity: $backgroundOpacity) {
            dismiss()
        }
        .onTap {
            withAnimation(.easeInOut(duration: 0.2)) {
                controlsVisible.toggle()
            }
        }
#else
        remoteImage(for: url)
#endif
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            ZStack {
                Color.clear
                    .frame(width: 56, height: 56)

                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .frame(width: 44, height: 44)
#if os(iOS)
                    .modifier(LiquidGlassCloseButtonStyle())
#else
                    .background(.black.opacity(0.55), in: Circle())
#endif
            }
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Close"))
    }

    private func remoteImage(for imageURL: URL) -> some View {
        LazyImage(url: imageURL) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if state.error != nil {
                ContentUnavailableView {
                    Label("Image Unavailable", systemImage: "photo")
                } description: {
                    Text("The artist image could not be loaded.")
                }
                .foregroundStyle(.white)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .priority(.high)
        .transaction { transaction in
            transaction.animation = nil
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if os(iOS)
private struct LiquidGlassCloseButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.clear.interactive(), in: Circle())
        } else {
            content
                .background(.black.opacity(0.55), in: Circle())
        }
    }
}
#endif
