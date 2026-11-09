import Foundation
import SwiftUI

struct FriendArtistRatingSummary: Equatable {
    struct Entry: Identifiable, Equatable {
        let profileID: String
        let badge: FestivalProfileBadge
        let preference: FestivalArtistPreference

        var id: String {
            profileID
        }
    }

    let entries: [Entry]

    var visibleEntries: [Entry] {
        Array(entries.prefix(3))
    }

    var remainingCount: Int {
        max(0, entries.count - 3)
    }

    func badgeZIndex(at index: Int) -> Double {
        Double(visibleEntries.count - index)
    }
}

struct FriendArtistRatingsBubble: View {
    enum Style {
        case capsule
        case plainInline
        case detailInline
    }

    let summary: FriendArtistRatingSummary
    var style: Style = .capsule

    private var visibleEntries: [FriendArtistRatingSummary.Entry] {
        summary.visibleEntries
    }

    private var remainingCount: Int {
        summary.remainingCount
    }

    var body: some View {
        HStack(spacing: entrySpacing) {
            ForEach(visibleEntries.indices, id: \.self) { index in
                let entry = visibleEntries[index]
                FriendArtistRatingBadge(entry: entry, style: style)
                    .zIndex(summary.badgeZIndex(at: index))
            }

            if remainingCount > 0 {
                FriendArtistRemainingCountBadge(
                    count: remainingCount,
                    style: style
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private var entrySpacing: CGFloat {
        switch style {
        case .capsule:
            return -6
        case .plainInline:
            return -6
        case .detailInline:
            return -4
        }
    }

    private var accessibilityText: String {
        let ratingDescriptions = summary.entries.map { entry in
            accessibilityDescription(for: entry)
        }

        return String.localizedStringWithFormat(
            NSLocalizedString(
                "artist.friend_ratings.accessibility.format",
                comment: "Accessible summary of friend artist ratings"
            ),
            ratingDescriptions.joined(separator: ", ")
        )
    }

    private func accessibilityDescription(
        for entry: FriendArtistRatingSummary.Entry
    ) -> String {
        let preference = entry.preference
        if preference.rating > 0 {
            let key = preference.rating == 1
                ? "artist.friend_rating.hearts.one"
                : "artist.friend_rating.hearts.other"
            return String.localizedStringWithFormat(
                NSLocalizedString(key, comment: "A friend's artist rating"),
                entry.badge.displayName,
                preference.rating
            )
        }

        return String.localizedStringWithFormat(
            NSLocalizedString(
                "artist.friend_rating.marker",
                comment: "A friend's alternative artist rating"
            ),
            entry.badge.displayName,
            localizedIconDescription(preference.iconName)
        )
    }

    private func localizedIconDescription(_ iconName: String?) -> String {
        guard let iconName else {
            return NSLocalizedString(
                "artist.icon.other",
                comment: "Generic alternative artist rating"
            )
        }

        let key = "artist.icon.\(iconName)"
        let localizedDescription = NSLocalizedString(
            key,
            comment: "Alternative artist rating"
        )
        guard localizedDescription != key else {
            return NSLocalizedString(
                "artist.icon.other",
                comment: "Generic alternative artist rating"
            )
        }
        return localizedDescription
    }
}

struct FriendArtistRatingBadge: View {
    let entry: FriendArtistRatingSummary.Entry
    let style: FriendArtistRatingsBubble.Style
    var diameter: CGFloat? = nil
    var borderOpacity = 1.0
    var preferenceOpacity = 1.0

    private var badgeDiameter: CGFloat {
        if let diameter { return diameter }
        switch style {
        case .capsule:
            return 22
        case .plainInline:
            return 20
        case .detailInline:
            return 24
        }
    }

    private var borderLineWidth: CGFloat {
        style == .detailInline ? 1 : 1.5
    }

    private var preferenceOffset: CGFloat {
        style == .detailInline ? 2 : 3
    }

    var body: some View {
        FestivalProfileBadgeAvatar(
            badge: entry.badge,
            diameter: badgeDiameter
        )
        .overlay {
            Circle()
                .strokeBorder(Color(.systemBackground), lineWidth: borderLineWidth)
                .opacity(borderOpacity)
        }
        .overlay(alignment: .bottomTrailing) {
            FriendArtistPreferenceDot(preference: entry.preference, style: style)
                .opacity(preferenceOpacity)
                .offset(x: preferenceOffset, y: preferenceOffset)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(entry.badge.displayName))
    }
}

struct FriendArtistRemainingCountBadge: View {
    let count: Int
    let style: FriendArtistRatingsBubble.Style

    private var badgeDiameter: CGFloat {
        switch style {
        case .capsule:
            return 22
        case .plainInline:
            return 20
        case .detailInline:
            return 24
        }
    }

    var body: some View {
        Text("+\(count)")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(width: badgeDiameter, height: badgeDiameter)
            .background {
                if style == .detailInline {
                    Circle().fill(Color(.secondarySystemBackground))
                } else {
                    Circle().fill(.thinMaterial)
                }
            }
            .overlay {
                Circle()
                    .strokeBorder(Color(.systemBackground), lineWidth: 1.5)
            }
            .accessibilityLabel(Text(accessibilityLabel))
    }

    private var accessibilityLabel: String {
        let key = count == 1
            ? "artist.friend_ratings.remaining.one"
            : "artist.friend_ratings.remaining.other"
        return String.localizedStringWithFormat(
            NSLocalizedString(key, comment: "More friend artist ratings"),
            count
        )
    }
}

private struct FriendArtistPreferenceDot: View {
    let preference: FestivalArtistPreference
    let style: FriendArtistRatingsBubble.Style

    @EnvironmentObject private var settings: UserSettings

    private var dotDiameter: CGFloat {
        switch style {
        case .capsule:
            return 14
        case .plainInline:
            return 13
        case .detailInline:
            return 12
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(dotColor)
                .overlay {
                    Circle()
                        .strokeBorder(Color(.systemBackground), lineWidth: 1)
                }

            if preference.rating > 0 {
                CompactRatingGlyph(
                    rating: preference.rating,
                    iconName: preference.iconName ?? settings.likeIcon,
                    color: .red,
                    size: 6.4,
                    spread: style == .detailInline ? 1.7 : 1.8
                )
            } else {
                Image(systemName: preference.iconName ?? "hand.thumbsdown.fill")
                    .font(
                        .system(
                            size: 6.5,
                            weight: .heavy
                        )
                    )
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: dotDiameter, height: dotDiameter)
    }

    private var dotColor: Color {
        Color(.systemBackground)
    }
}
