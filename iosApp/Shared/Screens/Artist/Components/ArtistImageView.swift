import Nuke
import NukeUI
import SwiftUI

enum ArtistImageLoadingStyle {
    case standard
    case quiet
}

struct ArtistImageView: View {
    let artist: Artist
    let fullImage: Bool
    let loadingStyle: ArtistImageLoadingStyle

    init(
        artist: Artist,
        fullImage: Bool,
        loadingStyle: ArtistImageLoadingStyle = .standard
    ) {
        self.artist = artist
        self.fullImage = fullImage
        self.loadingStyle = loadingStyle
    }

    private var selectedImageURL: URL? {
        if fullImage, let fullImageUrl = artist.fullImageUrl {
            return fullImageUrl
        }
        return artist.thumbImageUrl
    }

    private var placeholderImage: some View {
        Image(fullImage ? "placeholder" : "placeholder_thumb")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipped()
    }

    var body: some View {
        RemoteImageView(url: selectedImageURL, loadingStyle: loadingStyle,
                        identifier: { "artist-image-\($0)-\(artist.id)" }) {
            placeholderImage
        }
    }
}

@MainActor
func cachedRemoteImage(for url: URL, pipeline: ImagePipeline = .shared) -> PlatformImage? {
    guard let cached = pipeline.cache[Nuke.ImageRequest(url: url)], !cached.isPreview else { return nil }
    return cached.image
}

struct RemoteImageView<Placeholder: View>: View {
    let url: URL?
    let loadingStyle: ArtistImageLoadingStyle
    let identifier: (String) -> String
    let placeholder: () -> Placeholder

    init(url: URL?, loadingStyle: ArtistImageLoadingStyle = .standard,
         identifier: @escaping (String) -> String = { "remote-image-\($0)" },
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.loadingStyle = loadingStyle
        self.identifier = identifier
        self.placeholder = placeholder
    }

    private func loaded(_ image: Image) -> some View {
        image.resizable().aspectRatio(contentMode: .fill).clipped()
            .accessibilityIdentifier(identifier("loaded"))
    }

    @ViewBuilder private func cached(_ image: PlatformImage) -> some View {
        #if os(iOS)
        loaded(Image(uiImage: image))
        #else
        loaded(Image(nsImage: image))
        #endif
    }

    var body: some View {
        if let url {
            if let image = cachedRemoteImage(for: url) {
                cached(image)
            } else {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        loaded(image)
                    } else if state.error != nil {
                        placeholder().accessibilityIdentifier(identifier("failed"))
                    } else {
                        RemoteImageLoadingSkeleton(loadingStyle: loadingStyle)
                            .accessibilityIdentifier(identifier("loading"))
                    }
                }
                .priority(.high)
                .transaction { $0.animation = nil }
            }
        } else {
            placeholder().accessibilityIdentifier(identifier("placeholder"))
        }
    }
}

struct RemoteImageLoadingSkeleton: View {
    var loadingStyle: ArtistImageLoadingStyle = .standard
    @Environment(\.colorScheme) private var colorScheme
    @State private var skeletonShimmerPhase: CGFloat = -1

    private var skeletonBaseColor: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.08)
    }

    private var skeletonHighlightColor: Color {
        colorScheme == .dark ? .white.opacity(0.18) : .white.opacity(0.45)
    }

    @ViewBuilder var body: some View {
        if loadingStyle == .quiet {
            Rectangle()
                .fill(skeletonBaseColor)
        } else {
            Rectangle()
                .fill(skeletonBaseColor)
                .overlay {
                    GeometryReader { proxy in
                        let width = max(proxy.size.width, 1)

                        LinearGradient(
                            colors: [.clear, skeletonHighlightColor, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: width * 0.6)
                        .blur(radius: 10)
                        .offset(x: skeletonShimmerPhase * width * 1.8)
                    }
                    .clipped()
                }
                .overlay {
                    ProgressView()
                        .tint(colorScheme == .dark ? .white.opacity(0.9) : .secondary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .onAppear {
                    guard skeletonShimmerPhase == -1 else {
                        return
                    }

                    withAnimation(
                        .linear(duration: 1.15).repeatForever(autoreverses: false)
                    ) {
                        skeletonShimmerPhase = 1
                    }
                }
        }
    }
}

struct ArtistImageView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistImageView(artist: .example, fullImage: false)
    }
}
