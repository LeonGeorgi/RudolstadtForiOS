import SwiftUI

struct ArtistDetailHeaderView: View {
    let artist: Artist
    let imageTransitionNamespace: Namespace.ID

    @EnvironmentObject var dataStore: DataStore

    private var imageViewerTransitionID: String {
        "artist-full-image-\(artist.id)"
    }

    private var artistSubtitle: String? {
        artist.countries.isEmpty ? nil : artist.countries
    }

    private var artistLinks: ArtistLinks? {
        dataStore.artistLinks?[artist.name]
    }

    private var hasArtistLinks: Bool {
        artistLinks?.hasLinks ?? false
    }

    private var hasAnyLinks: Bool {
        artist.url != nil
            || artist.videoUrl != nil
            || artist.facebookUrl != nil
            || artist.instagramUrl != nil
            || hasArtistLinks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let fullImageUrl = artist.fullImageUrl {
                NavigationLink {
                    zoomableImageDestination(url: fullImageUrl)
                } label: {
                    artistImage
                }
                .buttonStyle(.plain)
            } else {
                artistImage
            }

            VStack(spacing: 4) {
                Text(artist.formattedName)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)

                if let artistSubtitle {
                    Text(artistSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)

            ratingView
                .padding(.top, 6)

            if hasAnyLinks {
                artistLinksView
                    .padding(.top, 2)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func zoomableImageDestination(url: URL) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            ZoomableRemoteImageViewer(url: url)
                .navigationTransition(
                    .zoom(sourceID: imageViewerTransitionID, in: imageTransitionNamespace)
                )
        } else {
            ZoomableRemoteImageViewer(url: url)
        }
    }

    @ViewBuilder
    private var artistImage: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            styledArtistImage
                .matchedTransitionSource(id: imageViewerTransitionID, in: imageTransitionNamespace)
        } else {
            styledArtistImage
        }
    }

    private var styledArtistImage: some View {
        ArtistImageView(artist: artist, fullImage: true)
            .aspectRatio(8.0 / 7.0, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 34)
    }

    private var ratingView: some View {
        ArtistRatingView(artist: artist)
        .padding(.horizontal, 34)
        .frame(maxWidth: .infinity)
    }

    private var artistLinksView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let videoUrl = artist.videoUrl {
                    LinkButton(label: "Video", scale: 0.6) {
                        Image("youtube")
                    } action: {
                        UIApplication.shared.open(videoUrl)
                    }
                }

                if let url = artist.url, let url = URL(string: url) {
                    LinkButton(label: "artist.website", scale: 1.0) {
                        Image(systemName: "globe")
                    } action: {
                        UIApplication.shared.open(url)
                    }
                }

                if let facebookUrl = artist.facebookUrl {
                    LinkButton(label: "Facebook", scale: 0.8) {
                        Image("facebook")
                    } action: {
                        UIApplication.shared.open(facebookUrl)
                    }
                }

                if let instagramUrl = artist.instagramUrl {
                    LinkButton(label: "Instagram", scale: 0.8) {
                        Image("instagram")
                    } action: {
                        UIApplication.shared.open(instagramUrl)
                    }
                }

                if let appleMusicURL = artistLinks?.appleMusicURL {
                    LinkButton(label: "Apple Music", scale: 1.0) {
                        Image(systemName: "music.note")
                    } action: {
                        UIApplication.shared.open(URL(string: appleMusicURL)!)
                    }
                }

                if let spotifyURL = artistLinks?.spotifyURL {
                    LinkButton(label: "Spotify", scale: 0.7) {
                        Image("spotify")
                    } action: {
                        UIApplication.shared.open(URL(string: spotifyURL)!)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
    }
}

private struct LinkButton: View {
    let label: LocalizedStringKey
    let scale: CGFloat
    let icon: () -> Image
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                icon()
                    .renderingMode(.template)
                    .frame(width: 16, height: 16)
                    .scaleEffect(scale)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Capsule())
        }
        .artistDetailLinkButtonStyle()
    }
}

private extension View {
    @ViewBuilder
    func artistDetailLinkButtonStyle() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self
                .buttonStyle(.glass)
        } else {
            self
                .buttonStyle(.plain)
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.16), lineWidth: 0.5)
                )
        }
    }
}
