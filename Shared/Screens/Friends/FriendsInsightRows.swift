#if os(iOS)
import SwiftUI

struct FriendsSeeAllRow: View {
    var body: some View {
        Label("friends.together.see_all", systemImage: "list.bullet")
    }
}

struct FriendEventSuggestionRow: View {
    let event: Event
    let profiles: [SharedFestivalProfile]

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            EventTimeBadge(event: event)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.artist.formattedName)
                    .font(.headline)
                    .lineLimit(2)

                Text(event.shortInformation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            FriendSavedEventBadges(
                eventID: event.id,
                profiles: profiles,
                style: .plainInline
            )
        }
    }
}

struct FriendArtistRecommendationRow: View {
    let recommendation: FriendArtistRecommendation

    @EnvironmentObject private var dataStore: DataStore

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ArtistImageView(artist: recommendation.artist, fullImage: false)
                .frame(width: 80, height: 70)
                .clipShape(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 7) {
                Text(recommendation.artist.formattedName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                metadata

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(recommendation.contributions) { contribution in
                        FriendArtistRecommendationContributionRow(
                            contribution: contribution,
                            showsFriendBadge: false
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var metadata: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let genreText {
                Text(genreText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let countryAndFlags {
                Text(countryAndFlags)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var genreText: String? {
        var seen = Set<String>()
        let browseGenreIDs: [String] = recommendation.artist.ai?.browseGenreIDs ?? []
        let labels = browseGenreIDs.compactMap { genreID -> String? in
            let label = dataStore.localizedBrowseGenreLabel(for: genreID)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty, !seen.contains(label) else {
                return nil
            }
            seen.insert(label)
            return label
        }
        .prefix(3)

        let value = labels.joined(separator: " • ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var flags: String? {
        let value = (recommendation.artist.ai?.flags ?? [])
            .joined(separator: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var countryAndFlags: String? {
        let country = recommendation.artist.countries.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let value = [country, flags]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

struct FriendArtistRecommendationTile: View {
    let recommendation: FriendArtistRecommendation

    @Environment(\.colorScheme) private var colorScheme
    private let cornerRadius: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            artwork

            VStack(alignment: .leading, spacing: 8) {
                Text(recommendation.artist.formattedName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(recommendation.contributions) { contribution in
                        FriendArtistRecommendationContributionRow(
                            contribution: contribution,
                            compact: true
                        )
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .top) {
                GeometryReader { proxy in
                    reflectionBackground(width: proxy.size.width)
                }
                .clipped()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: tileShadowColor, radius: 18, x: 0, y: 6)
        .contentShape(Rectangle())
    }

    private var artwork: some View {
        Color.clear
            .aspectRatio(8.0 / 7.0, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    ArtistImageView(artist: recommendation.artist, fullImage: true)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .clipped()
    }

    private var tileShadowColor: Color {
        colorScheme == .dark
            ? .black.opacity(0.28)
            : .black.opacity(0.10)
    }

    private var reflectionReadabilityOverlay: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground).opacity(colorScheme == .dark ? 0.24 : 0.56),
                Color(.systemBackground).opacity(colorScheme == .dark ? 0.42 : 0.72)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func reflectionBackground(width: CGFloat) -> some View {
        reflectedArtwork(width: width)
        .overlay(reflectionReadabilityOverlay)
        .clipped()
    }

    private func reflectedArtwork(width: CGFloat) -> some View {
        ArtistImageView(artist: recommendation.artist, fullImage: true)
            .frame(width: width, height: width * 7 / 8)
            .scaleEffect(x: 1, y: -1, anchor: .center)
            .blur(radius: 18, opaque: true)
            .clipped()
    }
}

private struct FriendArtistRecommendationContributionRow: View {
    let contribution: FriendArtistRecommendation.Contribution
    var compact = false
    var showsFriendBadge = false

    @EnvironmentObject private var settings: UserSettings

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            if showsFriendBadge {
                FestivalProfileBadgeAvatar(
                    badge: contribution.badge,
                    diameter: 20,
                    fontScale: 0.42
                )
            }

            contributionIcon
                .frame(width: compact ? 14 : 18)

            Text(reasonText)
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(.secondary)
                .lineLimit(compact ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var contributionIcon: some View {
        switch contribution.kind {
        case .savedEvent:
            Image(systemName: "calendar.badge.checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
        case .rating(let preference):
            CompactRatingGlyph(
                rating: preference.rating,
                iconName: preference.iconName ?? settings.likeIcon,
                color: .red,
                size: compact ? 7 : 8,
                spread: compact ? 2 : 2.4
            )
        }
    }

    private var reasonText: String {
        switch contribution.kind {
        case .savedEvent(let event):
            if compact {
                return String(
                    format: friendsLocalizedString(
                        "friends.recommendations.reason.saved_event.compact"
                    ),
                    contribution.badge.displayName,
                    FestivalDateUtilities.shortWeekDay(day: event.festivalDay),
                    event.timeAsString
                )
            } else {
                return String(
                    format: friendsLocalizedString("friends.recommendations.reason.saved_event"),
                    contribution.badge.displayName,
                    FestivalDateUtilities.fullWeekDay(day: event.festivalDay),
                    event.timeAsString,
                    event.stage.localizedName
                )
            }
        case .rating(let preference):
            let key = preference.rating == 1
                ? "friends.recommendations.reason.rating.one"
                : "friends.recommendations.reason.rating.other"
            return String(
                format: friendsLocalizedString(key),
                contribution.badge.displayName,
                Int64(preference.rating)
            )
        }
    }
}

struct FriendProfileListRow: View {
    let profile: SharedFestivalProfile
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            FestivalProfileBadgeAvatar(
                badge: profile.badge,
                diameter: 42
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.badge.displayName)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
struct FriendEventSuggestionRow_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        let environment = PreviewMockData.makeEnvironment(
            suiteName: "FriendEventSuggestionRowPreview"
        )
        let event = previewEvent(from: environment)

        List {
            FriendEventSuggestionRow(
                event: event,
                profiles: friendProfilesSavingEvent(
                    event,
                    from: environment.profile.syncStore.acceptedFriendProfiles
                )
            )
        }
        .previewEnvironment(environment)
        .previewLayout(.sizeThatFits)
    }

    private static func previewEvent(from environment: PreviewAppEnvironment) -> Event {
        let friendSavedEventIDs = Set(
            environment.profile.syncStore.acceptedFriendProfiles.flatMap(\.savedEventIDs)
        )
        return environment.festivalData.events.first { event in
            friendSavedEventIDs.contains(event.id)
        } ?? environment.festivalData.events.first ?? .example
    }
}
#endif
#endif
