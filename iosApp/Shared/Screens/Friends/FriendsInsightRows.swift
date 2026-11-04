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
        FestivalListRow {
            EventTimeBadge(event: event)
        } content: {
            FestivalListRowTitle(event.artist.formattedName)

            Text(event.shortInformation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } accessories: {
            FriendSavedEventBadges(
                eventID: event.id,
                profiles: profiles,
                style: .plainInline
            )
        }
    }
}

struct FriendArtistRecommendationCard: View {
    let recommendation: FriendArtistRecommendation

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .subheadline) private var titleSize: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 8) {
                Text(recommendation.artist.formattedName)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(recommendation.contributions) { contribution in
                        FriendArtistRecommendationContributionRow(
                            contribution: contribution, compact: true, showsBadge: true
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .background {
            FriendRecommendationArtwork(artist: recommendation.artist)
                .id(recommendation.artist.fullImageUrl ?? recommendation.artist.thumbImageUrl)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.08),
                radius: 10, x: 0, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct FriendArtistRecommendationTile: View {
    let recommendation: FriendArtistRecommendation

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var titleLineHeight: CGFloat = 20
    @ScaledMetric(relativeTo: .caption) private var reasonLineHeight: CGFloat = 16

    private var primaryContribution: FriendArtistRecommendation.Contribution? {
        recommendation.contributions.first {
            if case .savedEvent = $0.kind { return true }
            return false
        } ?? recommendation.contributions.first
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.artist.formattedName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .frame(maxWidth: .infinity, minHeight: titleLineHeight, alignment: .leading)

                if let contribution = primaryContribution {
                    FriendArtistRecommendationContributionRow(
                        contribution: contribution, compact: true
                    )
                    .frame(minHeight: reasonLineHeight, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        }
        .background {
            FriendRecommendationArtwork(artist: recommendation.artist)
                .id(recommendation.artist.fullImageUrl ?? recommendation.artist.thumbImageUrl)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.10),
                radius: 18, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct FriendArtistRecommendationContributionRow: View {
    @Environment(\.festivalAccentColor) private var festivalAccentColor
    let contribution: FriendArtistRecommendation.Contribution
    var compact = false
    var showsBadge = false

    @EnvironmentObject private var settings: UserSettings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var badgeDiameter: CGFloat = 18
    @ScaledMetric(relativeTo: .caption) private var badgeRowHeight: CGFloat = 24

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            if showsBadge {
                FestivalProfileBadgeAvatar(
                    badge: contribution.badge, diameter: badgeDiameter,
                    fontScale: 0.4, showsShadow: false
                )
                .accessibilityHidden(true)
            } else if !compact || showsRatingIcon {
                contributionIcon
                    .frame(width: compact ? 10 : 18)
            }

            Text(showsBadge ? informationText : reasonText)
                .font(.caption)
                .foregroundStyle(compact ? Color.white.opacity(0.85) : Color.secondary)
                .lineLimit(showsBadge ? nil : compact ? (dynamicTypeSize.isAccessibilitySize ? nil : 1) : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: showsBadge ? badgeRowHeight : nil, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(reasonText))
    }

    private var informationText: String {
        switch contribution.kind {
        case .savedEvent(let event):
            return "\(FestivalDateUtilities.shortWeekDay(day: event.festivalDay)) · \(event.timeAsString)"
        case .rating(let preference):
            let key = preference.rating == 1
                ? "artist.friend_rating.value.one" : "artist.friend_rating.value.other"
            return String(format: friendsLocalizedString(key), Int64(preference.rating))
        }
    }

    private var showsRatingIcon: Bool {
        if case .rating = contribution.kind { return true }
        return false
    }

    @ViewBuilder
    private var contributionIcon: some View {
        switch contribution.kind {
        case .savedEvent:
            if !compact {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(festivalAccentColor)
            }
        case .rating(let preference):
            CompactRatingGlyph(
                rating: preference.rating,
                iconName: preference.iconName ?? settings.likeIcon,
                color: compact ? .white : .red,
                size: compact ? 7 : 8,
                spread: compact ? 2 : 2.4
            )
        }
    }

    private var reasonText: String {
        switch contribution.kind {
        case .savedEvent(let event):
            if compact && !showsBadge {
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
                    from: environment.profile.friendProfilesStore.state.profiles
                )
            )
        }
        .previewEnvironment(environment)
        .previewLayout(.sizeThatFits)
    }

    private static func previewEvent(from environment: PreviewAppEnvironment) -> Event {
        let friendSavedEventIDs = Set(
            environment.profile.friendProfilesStore.state.profiles.flatMap { $0.saved.map(\.intValue) }
        )
        return environment.festivalData.events.first { event in
            friendSavedEventIDs.contains(event.id)
        } ?? environment.festivalData.events.first ?? .example
    }
}
#endif
#endif
