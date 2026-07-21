import SwiftUI

struct ArtistDetailHeaderView: View {
    let artist: Artist
    var showsInlineIdentity = true
    let currentTipID: String?
    let onTitleVisibilityChange: (Bool) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if showsInlineIdentity {
            VStack(alignment: .leading, spacing: 16) {
                ArtistDetailImageView(
                    artist: artist,
                    presentation: .inset
                )

                HStack(alignment: .bottom, spacing: 12) {
                    Text(artist.formattedName)
                        .font(
                            dynamicTypeSize.isAccessibilitySize
                                ? .title2.bold()
                                : .title.bold()
                        )
                        .multilineTextAlignment(
                            dynamicTypeSize.isAccessibilitySize ? .leading : .center
                        )
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                        .frame(
                            maxWidth: .infinity,
                            alignment: dynamicTypeSize.isAccessibilitySize
                                ? .leading
                                : .center
                        )
                        .layoutPriority(1)
                        .accessibilityHeading(.h1)
                        .onScrollVisibilityChange(threshold: 0.1) { isVisible in
                            onTitleVisibilityChange(isVisible)
                        }

                    ArtistRatingPopoverButton(
                        artist: artist,
                        currentTipID: currentTipID
                    )
                }
                .padding(.top, 4)
            }
        }
    }
}

struct ArtistDetailImageView: View {
    enum Presentation {
        case inset
        case edgeToEdgeParallax
    }

    private enum Layout {
        static let insetAspectRatio = 8.0 / 7.0
        static let edgeToEdgeAspectRatio = 1.0
        static let insetCornerRadius: CGFloat = 18
        static let parallaxFactor = 0.25
    }

    let artist: Artist
    let presentation: Presentation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.artistDetailTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isShowingFullImage = false

    var body: some View {
        Group {
            if let fullImageURL = artist.fullImageUrl {
                Button {
                    isShowingFullImage = true
                } label: {
                    presentedImage
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(imageButtonAccessibilityLabel))
                .fullScreenCover(isPresented: $isShowingFullImage) {
                    ZoomableRemoteImageViewer(url: fullImageURL)
                }
            } else {
                presentedImage
            }
        }
    }

    @ViewBuilder
    private var presentedImage: some View {
        switch presentation {
        case .inset:
            imageContent
                .aspectRatio(Layout.insetAspectRatio, contentMode: .fit)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: Layout.insetCornerRadius,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: Layout.insetCornerRadius,
                        style: .continuous
                    )
                    .stroke(theme.imageBorder, lineWidth: 0.5)
                }
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
                .padding(
                    .horizontal,
                    dynamicTypeSize.isAccessibilitySize ? 16 : 24
                )
        case .edgeToEdgeParallax:
            parallaxImage
        }
    }

    private var parallaxImage: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
            let baseHeight = proxy.size.width / Layout.edgeToEdgeAspectRatio
            let stretch = reduceMotion ? 0 : max(minY, 0)
            let parallaxOffset = reduceMotion
                ? 0
                : (minY > 0 ? -minY : -minY * Layout.parallaxFactor)

            imageContent
                .frame(
                    width: proxy.size.width,
                    height: baseHeight + stretch
                )
                .offset(y: parallaxOffset)
        }
        .aspectRatio(Layout.edgeToEdgeAspectRatio, contentMode: .fit)
    }

    private var imageContent: some View {
        Color.secondary.opacity(0.12)
            .overlay {
                ArtistImageView(artist: artist, fullImage: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
    }

    private var imageButtonAccessibilityLabel: String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "artist.image.open",
                comment: "Open an artist image full screen"
            ),
            artist.formattedName
        )
    }
}

private enum ArtistDetailLinkLayout {
    static let buttonSize: CGFloat = 50
    static let iconSize: CGFloat = 24
    static let spacing: CGFloat = 8
}

struct ArtistDetailLinksView: View {
    let artist: Artist
    let topPadding: CGFloat
    let openURL: (URL) -> Void

    @ObservedObject private var previewPlayer: AppleMusicPreviewPlayer

    init(
        artist: Artist,
        topPadding: CGFloat = 0,
        previewPlayer: AppleMusicPreviewPlayer,
        openURL: @escaping (URL) -> Void
    ) {
        self.artist = artist
        self.topPadding = topPadding
        _previewPlayer = ObservedObject(wrappedValue: previewPlayer)
        self.openURL = openURL
    }

    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var artistLinks: ArtistLinks? {
        if let exact = dataStore.artistLinks?[artist.name] {
            return exact
        }

        let normalizedName = normalizeArtistLinkKey(artist.name)
        return dataStore.artistLinks?[normalizedName]
    }

    private var hasArtistLinks: Bool {
        artistLinks?.hasLinks ?? false
    }

    private var appleMusicReference: AppleMusicCatalogReference? {
        artistLinks?.appleMusicPreviewReference
    }

    private var showsPreviewButton: Bool {
        appleMusicReference != nil
    }

    private var appleMusicLinkURL: URL? {
        guard let appleMusicURL = artistLinks?.appleMusicURL else {
            return nil
        }
        return URL(string: appleMusicURL)
    }

    private var hasMusicButtons: Bool {
        showsPreviewButton || appleMusicLinkURL != nil
    }

    private var hasAnyLinks: Bool {
        artist.url != nil
            || artist.facebookUrl != nil
            || artist.instagramUrl != nil
            || hasArtistLinks
    }

    private func openPreferInstalledApp(_ url: URL) {
        UIApplication.shared.open(
            url,
            options: [.universalLinksOnly: true]
        ) { success in
            if !success {
                openURL(url)
            }
        }
    }

    @ViewBuilder
    private var linkButtons: some View {
        if let url = artist.url, let url = URL(string: url) {
            LinkButton(label: "artist.website", scale: 1) {
                Image(systemName: "globe")
            } action: {
                openURL(url)
            }
        }

        if let facebookUrl = artist.facebookUrl {
            LinkButton(label: "Facebook", scale: 1.15) {
                Image("facebook")
            } action: {
                openPreferInstalledApp(facebookUrl)
            }
        }

        if let instagramUrl = artist.instagramUrl {
            LinkButton(label: "Instagram", scale: 1) {
                Image("instagram")
            } action: {
                openPreferInstalledApp(instagramUrl)
            }
        }

        if let spotifyURL = artistLinks?.spotifyURL,
           let url = URL(string: spotifyURL)
        {
            LinkButton(label: "Spotify", scale: 1.15) {
                Image("spotify")
            } action: {
                openPreferInstalledApp(url)
            }
        }
    }

    @ViewBuilder
    private var previewButton: some View {
        if let appleMusicReference {
            ArtistAppleMusicPreviewButton(
                player: previewPlayer,
                reference: appleMusicReference
            )
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    @ViewBuilder
    private var appleMusicLinkButton: some View {
        if let url = appleMusicLinkURL {
            LinkButton(label: "Apple Music", scale: 1) {
                Image(systemName: "music.note")
            } action: {
                openPreferInstalledApp(url)
            }
        }
    }

    private var musicButtons: some View {
        HStack(spacing: ArtistDetailLinkLayout.spacing) {
            previewButton
            appleMusicLinkButton
        }
    }

    private var linkButtonGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: ArtistDetailLinkLayout.buttonSize,
                        maximum: ArtistDetailLinkLayout.buttonSize
                    ),
                    spacing: ArtistDetailLinkLayout.spacing
                ),
            ],
            alignment: .leading,
            spacing: ArtistDetailLinkLayout.spacing
        ) {
            linkButtons
        }
    }

    @ViewBuilder
    private var artistActionsView: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: ArtistDetailLinkLayout.spacing) {
                if hasMusicButtons {
                    musicButtons
                }
                linkButtonGrid
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: ArtistDetailLinkLayout.spacing) {
                    if hasMusicButtons {
                        musicButtons
                    }
                    linkButtons
                }

                VStack(
                    alignment: .leading,
                    spacing: ArtistDetailLinkLayout.spacing
                ) {
                    if hasMusicButtons {
                        musicButtons
                    }
                    linkButtonGrid
                }
            }
        }
    }

    var body: some View {
        Group {
            if hasAnyLinks {
                VStack(alignment: .leading, spacing: 5) {
                    artistActionsView

                    if showsPreviewButton {
                        Text("artist.preview.attribution")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
                .padding(.top, topPadding)
            }
        }
    }
}

private struct LinkButton: View {
    let label: LocalizedStringKey
    let scale: CGFloat
    let icon: () -> Image
    let action: () -> Void

    @Environment(\.artistDetailTheme) private var theme

    var body: some View {
        Button(action: action) {
            icon()
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(
                    width: ArtistDetailLinkLayout.iconSize,
                    height: ArtistDetailLinkLayout.iconSize
                )
                .scaleEffect(scale)
                .frame(
                    width: ArtistDetailLinkLayout.buttonSize,
                    height: ArtistDetailLinkLayout.buttonSize
                )
                .contentShape(Circle())
        }
        .accessibilityLabel(Text(label))
        .artistDetailLinkButtonStyle(backgroundColor: theme.actionSurface)
    }
}

private extension View {
    func artistDetailLinkButtonStyle(backgroundColor: Color) -> some View {
        self
            .frame(
                width: ArtistDetailLinkLayout.buttonSize,
                height: ArtistDetailLinkLayout.buttonSize
            )
            .buttonBorderShape(.circle)
            .background(backgroundColor, in: Circle())
            .foregroundStyle(Color.accentColor)
    }
}
