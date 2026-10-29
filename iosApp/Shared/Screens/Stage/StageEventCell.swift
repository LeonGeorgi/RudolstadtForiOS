import SwiftUI

struct StageEventCell: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let event: Event
    let contextPreviewState: EventContextPreviewState
    let onToggleSaved: () -> Void

    var body: some View {
        FestivalListRow {
            ArtistListRowImage(artist: event.artist)
        } content: {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: FestivalListRowStyle.twoLineSpacing) {
                    eventTime
                    eventTag
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    eventTime
                    eventTag
                }
            }

            FestivalListRowTitle(event.artist.formattedName, lineLimit: 1)
        } accessories: {
            EventAccessories(
                event: event, state: contextPreviewState, style: .compact,
                onToggleSaved: onToggleSaved
            )
        }
        .eventContextMenu(event: event, state: contextPreviewState, onToggleSaved: onToggleSaved)
        .accessibilityIdentifier("event-\(event.id)")
    }

    private var eventTime: some View {
        Text(event.timeAsString)
            .font(FestivalListRowStyle.timeFont)
            .monospacedDigit()
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .layoutPriority(1)
    }

    @ViewBuilder
    private var eventTag: some View {
        if let tag = event.tag {
            Text(tag.localizedName.uppercased())
                .font(FestivalListRowStyle.tagFont)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        }
    }
}

struct StageEventCell_Previews: PreviewProvider {
    static var previews: some View {
        StageEventCell(
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
            .padding()
            .background(Color(.systemGroupedBackground))
    }
}
