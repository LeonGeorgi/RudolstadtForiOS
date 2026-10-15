import SwiftUI

struct ScheduleEventCell: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let event: Event
    let contextPreviewState: EventContextPreviewState
    let onToggleSaved: () -> Void

    private var isSaved: Bool {
        contextPreviewState.isSaved
    }

    private var artistRating: Int {
        contextPreviewState.artistRating
    }

    private var artistIconName: String? {
        contextPreviewState.artistIconName
    }

    private var friendProfilesWhoSavedEvent: [SharedFestivalProfile] {
        contextPreviewState.friendProfilesWhoSavedEvent
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }
        }
        .contextMenu {
            SaveEventButton(event: event, isSaved: isSaved, onToggle: onToggleSaved)
        } preview: {
            EventContextPreview(
                event: event,
                state: contextPreviewState
            )
        }
    }

    private var standardLayout: some View {
        HStack(alignment: .center, spacing: 12) {
            ArtistImageView(artist: event.artist, fullImage: false)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            standardEventInformation
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                if let tag = event.tag {
                    Text(tag.localizedName.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                Text(event.artist.formattedName)
                    .font(.headline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.timeAsString)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(event.stage.localizedName)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                ArtistImageView(artist: event.artist, fullImage: false)
                    .frame(width: 96, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()
                eventAccessories
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var standardEventInformation: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(event.timeAsString)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .monospacedDigit()

                        if let tag = event.tag {
                            Text(tag.localizedName.uppercased())
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Text(event.artist.formattedName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                eventAccessories
                    .fixedSize()
            }

            Text(event.stage.localizedName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var eventAccessories: some View {
        HStack(spacing: dynamicTypeSize.isAccessibilitySize ? 8 : 6) {
            if artistRating != 0 {
                CompactArtistRatingSymbol(
                    rating: artistRating,
                    iconName: artistIconName,
                    style: .inline
                )
                .scaleEffect(dynamicTypeSize.isAccessibilitySize ? 1.3 : 1)
                .frame(
                    width: dynamicTypeSize.isAccessibilitySize ? 30 : nil,
                    height: dynamicTypeSize.isAccessibilitySize ? 30 : nil
                )
            }
            if !friendProfilesWhoSavedEvent.isEmpty {
                FriendSavedEventBadges(
                    eventID: event.id,
                    profiles: friendProfilesWhoSavedEvent,
                    style: .plainInline
                )
                .frame(minWidth: 24, minHeight: 24, alignment: .center)
                .scaleEffect(dynamicTypeSize.isAccessibilitySize ? 1.25 : 1)
                .frame(
                    width: dynamicTypeSize.isAccessibilitySize ? 38 : nil,
                    height: dynamicTypeSize.isAccessibilitySize ? 30 : nil
                )
            }
            if dynamicTypeSize.isAccessibilitySize {
                EventSavedIcon(event: event, isSaved: isSaved, onToggle: onToggleSaved)
                    .font(.system(size: 24))
            } else {
                EventSavedIcon(
                    event: event,
                    isSaved: isSaved,
                    symbolAlignment: .trailing,
                    onToggle: onToggleSaved
                )
            }
        }
    }
}

struct ScheduleEventCell_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleEventCell(
            event: .example,
            contextPreviewState: EventContextPreviewState(
                isSaved: false,
                artistRating: 0,
                artistIconName: nil,
                friendProfilesWhoSavedEvent: [],
                artistNote: nil,
                isArtistSummaryEnabled: true
            ),
            onToggleSaved: {}
        )
    }
}
