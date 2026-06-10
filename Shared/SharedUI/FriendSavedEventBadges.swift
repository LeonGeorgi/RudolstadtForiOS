import SwiftUI

struct FriendSavedEventBadges: View {
    enum Style {
        case capsule
        case plainFloating
        case plainInline
        case plainFooter
    }

    private struct Entry: Identifiable {
        let profileID: String
        let badge: FestivalProfileBadge

        var id: String {
            profileID
        }
    }

    private struct Placement {
        let alignment: Alignment
        let xOffset: CGFloat
        let yOffset: CGFloat
    }

    let eventID: Int
    let profiles: [SharedFestivalProfile]
    var style: Style = .capsule

    private let maxVisibleBadges = 2

    private var entries: [Entry] {
        profiles.map { profile in
            Entry(profileID: profile.id, badge: profile.badge)
        }
    }

    private var visibleEntries: [Entry] {
        Array(entries.prefix(maxVisibleBadges))
    }

    private var remainingCount: Int {
        max(0, entries.count - maxVisibleBadges)
    }

    private var placement: Placement {
        let seed = abs(eventID)
        let alignment: Alignment
        let xOffset: CGFloat
        let yOffset: CGFloat

        switch style {
        case .capsule:
            let xDirection: CGFloat = seed.isMultiple(of: 2) ? 1 : -1
            alignment = xDirection > 0 ? .bottomTrailing : .bottomLeading
            xOffset = xDirection * CGFloat(6 + ((seed / 3) % 10))
            yOffset = CGFloat(7 + ((seed / 13) % 7))
        case .plainFloating:
            alignment = .bottom
            xOffset = 0
            yOffset = CGFloat(3 + (seed % 3))
        case .plainInline:
            alignment = .center
            xOffset = 0
            yOffset = 0
        case .plainFooter:
            alignment = .bottomTrailing
            xOffset = 0
            yOffset = 0
        }

        return Placement(alignment: alignment, xOffset: xOffset, yOffset: yOffset)
    }

    var body: some View {
        if !entries.isEmpty {
            HStack(spacing: badgeSpacing) {
                ForEach(visibleEntries) { entry in
                    FestivalProfileBadgeAvatar(
                        badge: entry.badge,
                        diameter: badgeDiameter,
                        fontScale: badgeFontScale
                    )
                }

                if remainingCount > 0 {
                    Text("+\(remainingCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isPlainStyle ? .primary : .secondary)
                        .shadow(
                            color: isPlainStyle ? .black.opacity(0.18) : .clear,
                            radius: 3,
                            y: 1
                        )
                }
            }
            .modifier(FriendSavedEventBadgesChrome(style: style))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(accessibilityText))
            .allowsHitTesting(false)
            .offset(x: placement.xOffset, y: placement.yOffset)
        }
    }

    var overlayAlignment: Alignment {
        placement.alignment
    }

    private var isPlainStyle: Bool {
        switch style {
        case .capsule:
            return false
        case .plainFloating, .plainInline, .plainFooter:
            return true
        }
    }

    private var badgeSpacing: CGFloat {
        switch style {
        case .capsule:
            return 6
        case .plainFooter:
            return -8
        case .plainFloating, .plainInline:
            return -6
        }
    }

    private var badgeDiameter: CGFloat {
        switch style {
        case .capsule:
            return 20
        case .plainFooter:
            return 16
        case .plainFloating, .plainInline:
            return 18
        }
    }

    private var badgeFontScale: CGFloat {
        switch style {
        case .capsule:
            return 0.34
        case .plainFloating, .plainInline, .plainFooter:
            return 0.5
        }
    }

    private var accessibilityText: String {
        let names = entries.map(\.badge.displayName)
        if names.count == 1, let firstName = names.first {
            return "\(firstName) saved this event"
        }
        return "\(names.joined(separator: ", ")) saved this event"
    }
}

private struct FriendSavedEventBadgesChrome: ViewModifier {
    let style: FriendSavedEventBadges.Style

    @ViewBuilder
    func body(content: Content) -> some View {
        switch style {
        case .capsule:
            content
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        case .plainFloating, .plainInline, .plainFooter:
            content
        }
    }
}
