import SwiftUI

struct ScheduleEventCell: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let event: Event
    let contextPreviewState: EventContextPreviewState
    let onToggleSaved: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }
        }
        .eventContextMenu(event: event, state: contextPreviewState, onToggleSaved: onToggleSaved)
    }

    private var standardLayout: some View {
        FestivalListRow(hasThirdLine: true) {
            ArtistListRowImage(artist: event.artist)
        } content: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(event.timeAsString)
                    .font(FestivalListRowStyle.timeFont)
                    .monospacedDigit()
                    .layoutPriority(1)

                if let tag = event.tag {
                    Text(tag.localizedName.uppercased())
                        .font(FestivalListRowStyle.tagFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            FestivalListRowTitle(event.artist.formattedName, lineLimit: 1)

            Text(event.stage.localizedName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .allowsTightening(true)
        } accessories: {
            eventAccessories
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                if let tag = event.tag {
                    Text(tag.localizedName.uppercased())
                        .font(FestivalListRowStyle.tagFont)
                        .foregroundStyle(.secondary)
                }

                FestivalListRowTitle(event.artist.formattedName)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.timeAsString)
                        .font(FestivalListRowStyle.timeFont)
                        .monospacedDigit()

                    Text(event.stage.localizedName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: FestivalListRowStyle.columnSpacing) {
                ArtistListRowImage(artist: event.artist)

                Spacer()
                eventAccessories
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var eventAccessories: some View {
        EventAccessories(
            event: event, state: contextPreviewState, style: .compact,
            onToggleSaved: onToggleSaved)
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
