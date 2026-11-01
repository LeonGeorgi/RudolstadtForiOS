import SwiftUI

/// Leaves row layout to the caller; the compact style retains the schedule's own spacing.
struct EventAccessories: View {
    enum Style {
        case standard
        case compact
        case withoutRating
    }

    let event: Event
    let state: EventContextPreviewState
    var style: Style = .standard
    var showsFriends = true
    let onToggleSaved: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var usesLargeControls: Bool {
        style == .compact && dynamicTypeSize.isAccessibilitySize
    }

    @ViewBuilder
    var body: some View {
        if style == .compact {
            HStack(spacing: usesLargeControls ? 8 : 6) { accessories }
        } else {
            accessories
        }
    }

    @ViewBuilder
    private var accessories: some View {
        if style != .withoutRating, state.artistRating != 0 {
            if style == .compact {
                CompactArtistRatingSymbol(rating: state.artistRating, iconName: state.artistIconName)
                    .scaleEffect(usesLargeControls ? 1.3 : 1)
                    .frame(
                        width: usesLargeControls ? 30 : nil,
                        height: usesLargeControls ? 30 : nil)
            } else {
                ArtistRatingSymbol(rating: state.artistRating, iconName: state.artistIconName)
                    .foregroundStyle(.secondary)
            }
        }

        if showsFriends, !state.friendProfilesWhoSavedEvent.isEmpty {
            let badges = FriendSavedEventBadges(
                eventID: event.id, profiles: state.friendProfilesWhoSavedEvent, style: .plainInline
            )
            .frame(minWidth: 24, minHeight: 24, alignment: .center)

            if usesLargeControls {
                badges.scaleEffect(1.25).frame(width: 38, height: 30)
            } else {
                badges
            }
        }

        if usesLargeControls {
            EventSavedIcon(event: event, isSaved: state.isSaved, onToggle: onToggleSaved)
                .font(.system(size: 24))
        } else {
            EventSavedIcon(
                event: event, isSaved: state.isSaved,
                symbolAlignment: style == .compact ? .trailing : .center,
                onToggle: onToggleSaved)
        }
    }
}
