import SwiftUI

struct SharedProfileSavedEventRow: View {
    @Environment(\.locale) private var locale

    let event: Event
    var dayLabel: String? = nil

    private var subtitle: String {
        let stageName = event.stage.localizedName(locale: locale)
        return [dayLabel, event.timeAsString, stageName.isEmpty ? nil : stageName]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var body: some View {
        FestivalListRow {
            ArtistListRowImage(artist: event.artist, loadingStyle: .quiet)
        } content: {
            FestivalListRowTitle(event.artist.formattedName)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SharedProfileRatedArtistRow: View {
    @EnvironmentObject private var currentProfile: FestivalProfileStore

    let artist: Artist
    let preference: FestivalArtistPreference

    var body: some View {
        FestivalListRow {
            ArtistListRowImage(artist: artist, loadingStyle: .quiet)
        } content: {
            FestivalListRowTitle(artist.formattedName)
            SharedProfileArtistRatingLabel(preference: preference)
        } accessories: {
            ArtistRatingListSlot(
                rating: currentProfile.rating(for: artist.id),
                iconName: currentProfile.iconName(forArtistID: artist.id),
                reservesSpace: false
            )
        }
        .accessibilityElement(children: .combine)
    }
}

struct SharedProfileArtistRatingLabel: View {
    @Environment(\.festivalAccentColor) private var festivalAccentColor

    let preference: FestivalArtistPreference

    var body: some View {
        HStack(spacing: 5) {
            if preference.rating > 0 {
                CompactRatingGlyph(
                    rating: preference.rating, iconName: preference.iconName ?? "heart.fill",
                    color: festivalAccentColor, size: 12, spread: 2
                )
                .accessibilityHidden(true)
                Text(String.localizedStringWithFormat(
                    NSLocalizedString("friends.detail.rating_value", comment: ""), preference.rating))
            } else {
                if let iconName = preference.iconName {
                    Image(systemName: iconName)
                        .foregroundStyle(festivalAccentColor)
                        .accessibilityHidden(true)
                }
                let key = "artist.icon.\(preference.iconName ?? "other")"
                let label = NSLocalizedString(key, comment: "")
                Text(label == key ? NSLocalizedString("artist.icon.other", comment: "") : label)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
