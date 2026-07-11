import Nuke
import NukeUI
import SwiftUI

struct ArtistImageView: View {
    let artist: Artist
    let fullImage: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var skeletonShimmerPhase: CGFloat = -1

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

    private var skeletonBaseColor: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.08)
    }

    private var skeletonHighlightColor: Color {
        colorScheme == .dark ? .white.opacity(0.18) : .white.opacity(0.45)
    }

    private var loadingSkeleton: some View {
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

    var body: some View {
        if let selectedImageURL {
            LazyImage(url: selectedImageURL) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                        .accessibilityIdentifier("artist-image-loaded-\(artist.id)")
                } else if state.error != nil {
                    placeholderImage
                        .accessibilityIdentifier("artist-image-failed-\(artist.id)")
                } else {
                    loadingSkeleton
                        .accessibilityIdentifier("artist-image-loading-\(artist.id)")
                }
            }
            .priority(.high)
            .transaction { transaction in
                transaction.animation = nil
            }
        } else {
            placeholderImage
                .accessibilityIdentifier("artist-image-placeholder-\(artist.id)")
        }
    }
}

struct ArtistImageView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistImageView(artist: .example, fullImage: false)
    }
}
