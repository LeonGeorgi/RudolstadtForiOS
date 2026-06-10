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
}

struct FriendArtistRatingsBubble: View {
    enum Style {
        case capsule
        case plainInline
    }

    let summary: FriendArtistRatingSummary
    var style: Style = .capsule

    private let maxVisibleRatings = 3

    private var visibleEntries: [FriendArtistRatingSummary.Entry] {
        Array(summary.entries.prefix(maxVisibleRatings))
    }

    private var remainingCount: Int {
        max(0, summary.entries.count - maxVisibleRatings)
    }

    var body: some View {
        HStack(spacing: entrySpacing) {
            ForEach(visibleEntries.indices, id: \.self) { index in
                let entry = visibleEntries[index]
                FriendArtistRatingBadge(entry: entry, style: style)
                    .zIndex(Double(visibleEntries.count - index))
            }

            if remainingCount > 0 {
                FriendArtistRemainingCountBadge(
                    count: remainingCount,
                    style: style
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityText))
    }

    private var entrySpacing: CGFloat {
        switch style {
        case .capsule:
            return -6
        case .plainInline:
            return -6
        }
    }

    private var accessibilityText: String {
        let ratingDescriptions = summary.entries.map { entry in
            let rating = entry.preference.rating
            if rating > 0 {
                let label = rating == 1 ? "1 like" : "\(rating) likes"
                return "\(entry.badge.displayName): \(label)"
            }

            return "\(entry.badge.displayName): \(entry.preference.iconName ?? "negative rating")"
        }

        return "Friend ratings: \(ratingDescriptions.joined(separator: ", "))"
    }
}

private struct FriendArtistRatingBadge: View {
    let entry: FriendArtistRatingSummary.Entry
    let style: FriendArtistRatingsBubble.Style

    private var badgeDiameter: CGFloat {
        switch style {
        case .capsule:
            return 22
        case .plainInline:
            return 20
        }
    }

    var body: some View {
        FestivalProfileBadgeAvatar(
            badge: entry.badge,
            diameter: badgeDiameter,
            fontScale: style == .capsule ? 0.34 : 0.42
        )
        .overlay(
            Circle()
                .strokeBorder(Color(.systemBackground), lineWidth: 1.5)
        )
        .overlay(alignment: .bottomTrailing) {
            FriendArtistPreferenceDot(preference: entry.preference, style: style)
                .offset(x: 3, y: 3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(entry.badge.displayName))
    }
}

private struct FriendArtistRemainingCountBadge: View {
    let count: Int
    let style: FriendArtistRatingsBubble.Style

    private var badgeDiameter: CGFloat {
        switch style {
        case .capsule:
            return 22
        case .plainInline:
            return 20
        }
    }

    var body: some View {
        Text("+\(count)")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(width: badgeDiameter, height: badgeDiameter)
            .background(.thinMaterial, in: Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color(.systemBackground), lineWidth: 1.5)
            )
            .accessibilityLabel(Text("\(count) more friend ratings"))
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
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(dotColor)
                .overlay(
                    Circle()
                        .strokeBorder(Color(.systemBackground), lineWidth: 1)
                )

            if preference.rating > 0 {
                CompactRatingGlyph(
                    rating: preference.rating,
                    iconName: preference.iconName ?? settings.likeIcon,
                    color: .red,
                    size: 6.4,
                    spread: 1.8
                )
            } else {
                Image(systemName: preference.iconName ?? "hand.thumbsdown.fill")
                    .font(.system(size: 6.5, weight: .heavy))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: dotDiameter, height: dotDiameter)
        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
    }

    private var dotColor: Color {
        Color(.systemBackground)
    }
}
