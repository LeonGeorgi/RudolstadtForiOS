import AVFoundation
import SwiftUI

@MainActor
final class AppleMusicPreviewPlayer: ObservableObject {
    enum PlaybackState: Equatable {
        case idle
        case loading
        case ready
        case playing
        case paused
        case finished
        case unavailable
    }

    private enum Constants {
        static let fallbackDuration: TimeInterval = 30
        static let progressUpdateInterval: TimeInterval = 0.25
    }

    @Published private(set) var state: PlaybackState = .idle
    @Published private(set) var progress = 0.0
    @Published private(set) var trackName: String?

    private let previewService: AppleMusicPreviewService
    private var loadTask: Task<Void, Never>?
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var itemStatusObservation: NSKeyValueObservation?
    private var playbackObserverTokens: [NSObjectProtocol] = []
    private var isAudioSessionActive = false
    private(set) var reference: AppleMusicCatalogReference?

    init(
        previewService: AppleMusicPreviewService = AppleMusicPreviewService()
    ) {
        self.previewService = previewService
    }

    deinit {
        loadTask?.cancel()
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        itemStatusObservation?.invalidate()
        playbackObserverTokens.forEach {
            NotificationCenter.default.removeObserver($0)
        }
    }

    func togglePlayback(for reference: AppleMusicCatalogReference) {
        if self.reference != reference {
            loadPreview(for: reference)
            return
        }

        switch state {
        case .ready, .paused:
            startPlayback()
        case .playing:
            pause()
        case .finished:
            player?.seek(to: .zero)
            progress = 0
            startPlayback()
        case .idle, .unavailable:
            loadPreview(for: reference)
        case .loading:
            break
        }
    }

    func pause() {
        guard state == .playing else {
            return
        }
        player?.pause()
        state = .paused
        deactivateAudioSession()
    }

    func stop() {
        loadTask?.cancel()
        loadTask = nil
        clearPlayer()
        reference = nil
        trackName = nil
        progress = 0
        state = .idle
        deactivateAudioSession()
    }

    var elapsedSeconds: Int {
        Int((progress * playbackDuration).rounded())
    }

    var durationSeconds: Int {
        Int(playbackDuration.rounded())
    }

    private func loadPreview(for reference: AppleMusicCatalogReference) {
        stop()
        self.reference = reference
        state = .loading

        loadTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let preview = try await previewService.fetchPreview(
                    for: reference
                )
                try Task.checkCancellation()
                guard self.reference == reference else {
                    return
                }
                install(preview: preview)
                startPlayback()
            } catch is CancellationError {
                return
            } catch {
                guard self.reference == reference else {
                    return
                }
                state = .unavailable
            }
        }
    }

    private func install(preview: AppleMusicPreview) {
        clearPlayer()

        let item = AVPlayerItem(url: preview.previewURL)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true

        self.player = player
        trackName = preview.trackName
        progress = 0
        state = .ready
        observePlayback(of: item, with: player)
    }

    private func startPlayback() {
        guard let player else {
            return
        }
        activateAudioSession()
        player.play()
        state = .playing
    }

    private func observePlayback(of item: AVPlayerItem, with player: AVPlayer) {
        let interval = CMTime(
            seconds: Constants.progressUpdateInterval,
            preferredTimescale: 600
        )
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.updateProgress(for: time)
            }
        }

        itemStatusObservation = item.observe(
            \.status,
            options: [.initial, .new]
        ) { [weak self] item, _ in
            guard item.status == .failed else {
                return
            }
            Task { @MainActor [weak self] in
                self?.failPlayback()
            }
        }

        let notificationCenter = NotificationCenter.default
        playbackObserverTokens = [
            notificationCenter.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.finishPlayback()
                }
            },
            notificationCenter.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.failPlayback()
                }
            },
        ]
    }

    private func updateProgress(for time: CMTime) {
        let elapsed = time.seconds
        guard elapsed.isFinite else {
            return
        }
        progress = min(max(elapsed / playbackDuration, 0), 1)
    }

    private func finishPlayback() {
        guard player != nil else {
            return
        }
        progress = 1
        state = .finished
        deactivateAudioSession()
    }

    private func failPlayback() {
        guard player != nil else {
            return
        }
        clearPlayer()
        progress = 0
        state = .unavailable
        deactivateAudioSession()
    }

    private var playbackDuration: TimeInterval {
        guard let duration = player?.currentItem?.duration.seconds,
              duration.isFinite,
              duration > 0
        else {
            return Constants.fallbackDuration
        }
        return duration
    }

    private func clearPlayer() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil

        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        playbackObserverTokens.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        playbackObserverTokens.removeAll()

        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    private func activateAudioSession() {
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default)
        do {
            try audioSession.setActive(true)
            isAudioSessionActive = true
        } catch {
            isAudioSessionActive = false
        }
        #endif
    }

    private func deactivateAudioSession() {
        #if os(iOS)
        guard isAudioSessionActive else {
            return
        }
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
        isAudioSessionActive = false
        #endif
    }
}

struct ArtistAppleMusicPreviewButton: View {
    private enum Layout {
        static let width: CGFloat = 110
        static let height: CGFloat = 50
        static let iconSize: CGFloat = 18
        static let accessibilityIconSize: CGFloat = 22
        static let progressWidth: CGFloat = 48
        static let progressHeight: CGFloat = 5
        static let accessibilityWidth: CGFloat = 140
        static let accessibilityHeight: CGFloat = 60
        static let accessibilityProgressWidth: CGFloat = 64
    }

    @ObservedObject var player: AppleMusicPreviewPlayer
    let reference: AppleMusicCatalogReference
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button {
            player.togglePlayback(for: reference)
        } label: {
            HStack(spacing: 12) {
                playbackIcon
                    .frame(
                        width: iconSize,
                        height: iconSize
                    )

                GeometryReader { proxy in
                    Capsule()
                        .fill(.white.opacity(0.28))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(.white)
                                .frame(
                                    width: proxy.size.width * player.progress
                                )
                        }
                }
                .frame(
                    width: progressWidth,
                    height: Layout.progressHeight
                )
                .accessibilityHidden(true)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(width: buttonWidth, height: buttonHeight)
            .background(Color.accentColor, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isPlaybackAvailable)
        .opacity(player.state == .loading ? 0.72 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(Text(accessibilityValue))
    }

    private var buttonWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? Layout.accessibilityWidth
            : Layout.width
    }

    private var buttonHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? Layout.accessibilityHeight
            : Layout.height
    }

    private var progressWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? Layout.accessibilityProgressWidth
            : Layout.progressWidth
    }

    private var iconSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? Layout.accessibilityIconSize
            : Layout.iconSize
    }

    @ViewBuilder
    private var playbackIcon: some View {
        if player.state == .loading {
            ProgressView()
                .controlSize(.small)
                .tint(.white)
        } else {
            Image(
                systemName: player.state == .playing
                    ? "pause.fill"
                    : "play.fill"
            )
            .font(.system(size: iconSize, weight: .semibold))
        }
    }

    private var isPlaybackAvailable: Bool {
        switch player.state {
        case .idle, .ready, .playing, .paused, .finished, .unavailable:
            return true
        case .loading:
            return false
        }
    }

    private var accessibilityLabel: String {
        if player.state == .loading {
            return NSLocalizedString(
                "artist.preview.loading",
                comment: "Apple Music preview loading accessibility label"
            )
        }

        let key = player.state == .playing
            ? "artist.preview.pause.format"
            : "artist.preview.play.format"
        return String.localizedStringWithFormat(
            NSLocalizedString(
                key,
                comment: "Apple Music preview playback accessibility label"
            ),
            player.trackName ?? "Apple Music"
        )
    }

    private var accessibilityValue: String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "artist.preview.progress.format",
                comment: "Elapsed and total Apple Music preview seconds"
            ),
            player.elapsedSeconds,
            player.durationSeconds
        )
    }
}
