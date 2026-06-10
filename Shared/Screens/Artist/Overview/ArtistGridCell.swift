import SwiftUI

struct ArtistGridCell: View {
    let artist: Artist
    let imageTransitionNamespace: Namespace.ID
    let artistRating: Int
    let artistIconName: String?
    let friendRatingSummary: FriendArtistRatingSummary?

    private var flags: String? {
        let value = (artist.ai?.flags ?? []).joined(separator: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var countryAndFlags: String? {
        let country = artist.countries.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let value = [country, flags]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.12))

                ArtistImageView(artist: artist, fullImage: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                ratingBadge
                    .padding(8)
            }
            .overlay(alignment: .topTrailing) {
                if let friendRatingSummary {
                    FriendArtistRatingsBubble(summary: friendRatingSummary)
                        .padding(8)
                }
            }
            .aspectRatio(8 / 7, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 0.5)
            )
            .artistImageTransitionSource(
                id: artist.id,
                namespace: imageTransitionNamespace
            )

            Text(artist.formattedName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.94)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let countryAndFlags {
                Text(countryAndFlags)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.94)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var ratingBadge: some View {
        if artistRating != 0 {
            CompactArtistRatingSymbol(
                rating: artistRating,
                iconName: artistIconName,
                style: .imageOverlay,
                negativeColor: .white,
                negativeShadowColor: .black.opacity(0.5),
                negativeShadowRadius: 7,
                negativeShadowY: 3
            )
        } else {
            Color.clear
        }
    }
}

#if DEBUG
private struct ArtistGridCellPreviewCase: Identifiable {
    let title: String
    let artist: Artist
    let artistRating: Int
    let artistIconName: String?
    let friendRatingSummary: FriendArtistRatingSummary?

    var id: String {
        title
    }
}

@MainActor
private struct ArtistGridCellPreview: View {
    @Namespace private var namespace

    private var previewCases: [ArtistGridCellPreviewCase] {
        [
            ArtistGridCellPreviewCase(
                title: "Stage / plain",
                artist: artist(type: .stage),
                artistRating: 0,
                artistIconName: nil,
                friendRatingSummary: nil
            ),
            ArtistGridCellPreviewCase(
                title: "Stage / rated",
                artist: artist(type: .stage, offset: 1),
                artistRating: 3,
                artistIconName: nil,
                friendRatingSummary: nil
            ),
            ArtistGridCellPreviewCase(
                title: "Dance / friend",
                artist: artist(type: .dance),
                artistRating: 0,
                artistIconName: nil,
                friendRatingSummary: friendSummary(count: 1, artistID: 3001)
            ),
            ArtistGridCellPreviewCase(
                title: "Dance / rated + friends",
                artist: artist(type: .dance, offset: 1),
                artistRating: 2,
                artistIconName: nil,
                friendRatingSummary: friendSummary(count: 2, artistID: 3002)
            ),
            ArtistGridCellPreviewCase(
                title: "Street / negative",
                artist: artist(type: .street),
                artistRating: -1,
                artistIconName: "questionmark.circle.fill",
                friendRatingSummary: nil
            ),
            ArtistGridCellPreviewCase(
                title: "Street / full",
                artist: artist(type: .street, offset: 1),
                artistRating: 1,
                artistIconName: nil,
                friendRatingSummary: friendSummary(count: 2, artistID: 3003)
            ),
            ArtistGridCellPreviewCase(
                title: "Other / plain",
                artist: artist(type: .other),
                artistRating: 0,
                artistIconName: nil,
                friendRatingSummary: nil
            ),
            ArtistGridCellPreviewCase(
                title: "Other / friend icon",
                artist: artist(type: .other, offset: 1),
                artistRating: -1,
                artistIconName: "hand.thumbsdown.fill",
                friendRatingSummary: friendSummary(count: 1, artistID: 3004)
            ),
        ]
    }

    var body: some View {
        let columns = Array(
            repeating: GridItem(.fixed(150), spacing: 16, alignment: .top),
            count: 2
        )

        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(previewCases) { previewCase in
                VStack(alignment: .leading, spacing: 6) {
                    ArtistGridCell(
                        artist: previewCase.artist,
                        imageTransitionNamespace: namespace,
                        artistRating: previewCase.artistRating,
                        artistIconName: previewCase.artistIconName,
                        friendRatingSummary: previewCase.friendRatingSummary
                    )

                    Text(previewCase.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding()
    }

    private func artist(type: ArtistType, offset: Int = 0) -> Artist {
        let artists = PreviewMockData.festivalData.artists
            .filter { artist in
                artist.artistType == type && artist.fullImageUrl != nil
            }

        guard !artists.isEmpty else {
            return Artist.example
        }

        return artists[min(offset, artists.count - 1)]
    }

    private func friendSummary(
        count: Int,
        artistID: Int
    ) -> FriendArtistRatingSummary {
        let badges = [
            FestivalProfileBadge(displayName: "Maya", colorHex: "#B54E9B"),
            FestivalProfileBadge(displayName: "Sam", colorHex: "#23867A"),
            FestivalProfileBadge(displayName: "Jo", colorHex: "#D49A1F"),
        ]
        let entries = badges.prefix(count).enumerated().map { index, badge in
            FriendArtistRatingSummary.Entry(
                profileID: "artist-grid-preview-\(index)",
                badge: badge,
                preference: FestivalArtistPreference(
                    artistID: artistID,
                    rating: index == 0 ? 2 : -1,
                    iconName: index == 0 ? nil : "questionmark.circle.fill"
                )
            )
        }

        return FriendArtistRatingSummary(entries: entries)
    }
}

struct ArtistGridCell_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        ArtistGridCellPreview()
            .previewMockEnvironment(suiteName: "ArtistGridCellPreview")
            .previewLayout(.sizeThatFits)
    }
}
#endif
