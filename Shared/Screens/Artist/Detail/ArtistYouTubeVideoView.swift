import NukeUI
import SwiftUI
import YouTubePlayerKit

struct ArtistYouTubeVideoView: View {
    let videoID: String
    let videoURL: URL

    @Environment(\.artistDetailTheme) private var theme
    @State private var isPlayerLoaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtistDetailSectionHeader("artist.video")

            YouTubeVideoView(
                videoID: videoID,
                videoURL: videoURL,
                backgroundColor: theme.contentSurface,
                borderColor: theme.imageBorder,
                isPlayerLoaded: isPlayerLoaded
            ) {
                isPlayerLoaded = true
            }
        }
    }
}

struct YouTubeVideoView: View {
    let videoID: String
    let videoURL: URL
    let backgroundColor: Color
    let borderColor: Color
    let cornerRadius: CGFloat
    let isPlayerLoaded: Bool
    let loadPlayer: () -> Void

    init(
        videoID: String,
        videoURL: URL,
        backgroundColor: Color = Color.secondary.opacity(0.12),
        borderColor: Color = Color.primary.opacity(0.12),
        cornerRadius: CGFloat = 14,
        isPlayerLoaded: Bool,
        loadPlayer: @escaping () -> Void
    ) {
        self.videoID = videoID
        self.videoURL = videoURL
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.isPlayerLoaded = isPlayerLoaded
        self.loadPlayer = loadPlayer
    }

    var body: some View {
        Color.clear
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                Group {
                    if isPlayerLoaded {
                        LoadedYouTubePlayerView(
                            videoID: videoID,
                            videoURL: videoURL
                        )
                    } else {
                        thumbnailButton
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
    }

    private var thumbnailButton: some View {
        Button(action: loadPlayer) {
            ZStack {
                thumbnail

                Color.black.opacity(0.16)

                Label("youtube.video.load", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Color.black.opacity(0.72),
                        in: Capsule(style: .continuous)
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("youtube.video.load")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbnailURL = youtubeThumbnailURL(for: videoID) {
            LazyImage(url: thumbnailURL) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else if state.error != nil {
                    thumbnailPlaceholder
                } else {
                    thumbnailPlaceholder
                        .overlay {
                            ProgressView()
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        } else {
            thumbnailPlaceholder
        }
    }

    private var thumbnailPlaceholder: some View {
        backgroundColor
            .overlay {
                Image(systemName: "video")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
}

private struct LoadedYouTubePlayerView: View {
    let videoURL: URL

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var player: YouTubePlayer

    init(videoID: String, videoURL: URL) {
        self.videoURL = videoURL
        _player = StateObject(
            wrappedValue: YouTubePlayer(
                source: .video(id: videoID),
                parameters: .init(
                    autoPlay: false,
                    showControls: true
                ),
                configuration: .init(
                    useNonPersistentWebsiteDataStore: true
                )
            )
        )
    }

    var body: some View {
        YouTubePlayerView(
            player,
            idleOverlay: {
                loadingView
            },
            readyOverlay: {
                EmptyView()
            },
            errorOverlay: { _ in
                unavailableView
            }
        )
        .onChange(of: scenePhase) { newPhase in
            if newPhase != .active {
                pause()
            }
        }
        .onDisappear {
            pause()
        }
    }

    private var loadingView: some View {
        ProgressView("youtube.video.loading")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }

    private var unavailableView: some View {
        VStack(spacing: 10) {
            Image(systemName: "play.slash")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("youtube.video.unavailable")
                .font(.subheadline)
                .multilineTextAlignment(.center)

            Button("youtube.video.open_youtube") {
                openURL(videoURL)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func pause() {
        Task {
            try? await player.pause()
        }
    }
}

#if DEBUG
struct ArtistYouTubeVideoView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        Group {
            if let videoURL = URL(
                string: "https://www.youtube.com/watch?v=QNJL6nfu__Q"
            ) {
                ArtistYouTubeVideoView(
                    videoID: "QNJL6nfu__Q",
                    videoURL: videoURL
                )
                .padding()
                .previewMockEnvironment(suiteName: "ArtistYouTubeVideoViewPreview")
                .previewLayout(.sizeThatFits)
            }
        }
    }
}
#endif
