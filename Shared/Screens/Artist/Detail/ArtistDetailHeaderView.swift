import SwiftUI

struct ArtistDetailHeaderView: View {
    let artist: Artist

    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingFullImage = false

    private var countryAndFlags: String? {
        let country = artist.countries.trimmingCharacters(in: .whitespacesAndNewlines)
        let flags = artist.ai?.flags.joined(separator: "") ?? ""
        let countryWithFlags = [country, flags]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return countryWithFlags.isEmpty ? nil : countryWithFlags
    }

    private var localizedTags: [String] {
        let tags = artist.ai?.localizedTags ?? []
        var seen = Set<String>()
        return tags.compactMap { tag in
            let label = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else {
                return nil
            }
            if seen.contains(label) {
                return nil
            }
            seen.insert(label)
            return label
        }
    }

    private var hasMetadata: Bool {
        countryAndFlags != nil || !localizedTags.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let fullImageUrl = artist.fullImageUrl {
                Button {
                    isShowingFullImage = true
                } label: {
                    artistImage
                }
                .buttonStyle(.plain)
                .fullScreenCover(isPresented: $isShowingFullImage) {
                    ZoomableRemoteImageViewer(url: fullImageUrl)
                }
            } else {
                artistImage
            }

            VStack(spacing: 4) {
                Text(artist.formattedName)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)

                if hasMetadata {
                    VStack(spacing: 3) {
                        if let countryAndFlags {
                            Text(countryAndFlags)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        if !localizedTags.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles.2")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(localizedTags.joined(separator: " • "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)

        }
        .padding(.top, 4)
    }

    private var imageStrokeColor: Color {
        colorScheme == .dark ? .white.opacity(0.22) : .black.opacity(0.15)
    }

    private var artistImage: some View {
        ArtistImageView(artist: artist, fullImage: true)
            .aspectRatio(8.0 / 7.0, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(imageStrokeColor, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: 8)
            .padding(.horizontal, 40)
    }

}

struct ArtistDetailLinksView: View {
    let artist: Artist
    let openURL: (URL) -> Void

    @EnvironmentObject var dataStore: DataStore

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

    private var hasAnyLinks: Bool {
        artist.url != nil
            || artist.videoUrl != nil
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

    private var artistLinksView: some View {
        HStack(spacing: 12) {
            if let videoUrl = artist.videoUrl {
                LinkButton(label: "Video", scale: 0.6) {
                    Image("youtube")
                } action: {
                    openPreferInstalledApp(videoUrl)
                }
            }

            if let url = artist.url, let url = URL(string: url) {
                LinkButton(label: "artist.website", scale: 1.0) {
                    Image(systemName: "globe")
                } action: {
                    openURL(url)
                }
            }

            if let facebookUrl = artist.facebookUrl {
                LinkButton(label: "Facebook", scale: 0.8) {
                    Image("facebook")
                } action: {
                    openPreferInstalledApp(facebookUrl)
                }
            }

            if let instagramUrl = artist.instagramUrl {
                LinkButton(label: "Instagram", scale: 0.8) {
                    Image("instagram")
                } action: {
                    openPreferInstalledApp(instagramUrl)
                }
            }

            if let appleMusicURL = artistLinks?.appleMusicURL, let url = URL(string: appleMusicURL) {
                LinkButton(label: "Apple Music", scale: 1.0) {
                    Image(systemName: "music.note")
                } action: {
                    openPreferInstalledApp(url)
                }
            }

            if let spotifyURL = artistLinks?.spotifyURL, let url = URL(string: spotifyURL) {
                LinkButton(label: "Spotify", scale: 0.7) {
                    Image("spotify")
                } action: {
                    openPreferInstalledApp(url)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    var body: some View {
        if hasAnyLinks {
            artistLinksView
        }
    }
}

private struct LinkButton: View {
    let label: LocalizedStringKey
    let scale: CGFloat
    let icon: () -> Image
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            icon()
                .renderingMode(.template)
                .frame(width: 18, height: 18)
                .scaleEffect(scale)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .accessibilityLabel(Text(label))
        .artistDetailLinkButtonStyle()
    }
}

private extension View {
    func artistDetailLinkButtonStyle() -> some View {
        self
            .frame(width: 50, height: 50)
            .buttonBorderShape(.circle)
            .background(Color.primary.opacity(0.12), in: Circle())
            .foregroundStyle(.foreground)
    }
}
