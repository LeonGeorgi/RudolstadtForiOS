//
//  ArtistConcertItem.swift
//  RudolstadtForiOS
//
//  Created by Leon on 25.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

private struct ArtistNavigationHandlerKey: EnvironmentKey {
    static let defaultValue: ((AppNavigationRoute) -> Void)? = nil
}

extension EnvironmentValues {
    var artistNavigationHandler: ((AppNavigationRoute) -> Void)? {
        get { self[ArtistNavigationHandlerKey.self] }
        set { self[ArtistNavigationHandlerKey.self] = newValue }
    }
}

struct ArtistEventCell: View {
    let event: Event
    let intersectingEvents: [Event]
    let contextPreviewState: EventContextPreviewState
    var showsTrailingAccessories = true
    var timeBadgeSize: CGFloat = 52
    let onToggleSaved: () -> Void
    @Environment(\.artistNavigationHandler) private var navigate
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State var selectedCollisionArtist: Artist? = nil

    private var friendProfilesWhoSavedEvent: [SharedFestivalProfile] {
        contextPreviewState.friendProfilesWhoSavedEvent
    }

    var body: some View {
        eventContent
            .navigationDestination(
                isPresented: Binding {
                    selectedCollisionArtist != nil
                } set: { value in
                    if !value {
                        selectedCollisionArtist = nil
                    }
                }
            ) {
                if let artist = selectedCollisionArtist {
                    ArtistDetailView(
                        artist: artist,
                        highlightedEventId: event.id
                    )
                }
            }
            .eventContextMenu(event: event, state: contextPreviewState, onToggleSaved: onToggleSaved) {
                ForEach(intersectingEvents) { intersectingEvent in
                    Button {
                        if let navigate {
                            navigate(
                                .artist(
                                    id: intersectingEvent.artist.id,
                                    highlightedEventId: event.id,
                                    transitionSourceID: nil
                                )
                            )
                        } else {
                            selectedCollisionArtist = intersectingEvent.artist
                        }
                    } label: {
                        Label(intersectingEvent.artist.formattedName, systemImage: "exclamationmark.circle")
                    }
                }
            }
    }

    private var eventContent: some View {
        FestivalListRow(hasThirdLine: metadataLineCount > 2) {
            EventTimeBadge(event: event, size: timeBadgeSize)
                .dynamicTypeSize(dynamicTypeSize.isAccessibilitySize ? .large : dynamicTypeSize)

        } content: {
            eventMetadata
        } accessories: {
            if showsTrailingAccessories {
                trailingAccessories
                    .dynamicTypeSize(
                        dynamicTypeSize.isAccessibilitySize ? .accessibility1 : dynamicTypeSize
                    )
            } else if !friendProfilesWhoSavedEvent.isEmpty {
                friendBadges
            }
        }
    }

    private var metadataLineCount: Int {
        1 + (event.tag == nil ? 0 : 1) + (event.startDate == nil ? 1 : 0)
            + intersectingEvents.count
    }

    @ViewBuilder
    private var eventMetadata: some View {
        eventTag

        if event.startDate == nil {
            Text(event.timeAsString)
                .font(FestivalListRowStyle.timeFont)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        FestivalListRowTitle(event.stage.localizedName, lineLimit: 1)

        intersectingEventsView
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

    private var friendBadges: some View {
        FriendSavedEventBadges(
            eventID: event.id,
            profiles: friendProfilesWhoSavedEvent,
            style: .plainInline
        )
        .frame(minWidth: 24, minHeight: 24, alignment: .center)
    }

    @ViewBuilder
    private var trailingAccessories: some View {
        EventAccessories(
            event: event, state: contextPreviewState, style: .withoutRating,
            onToggleSaved: onToggleSaved)

        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary.opacity(0.75))
    }

    @ViewBuilder
    private var intersectingEventsView: some View {
        if !intersectingEvents.isEmpty {
            ForEach(intersectingEvents) { (intersectingEvent: Event) in
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption)
                    Text(
                        String(
                            format: NSLocalizedString(
                                "event.intersecting.with",
                                comment: ""
                            ),
                            intersectingEvent.artist.formattedName
                        )
                    )
                    .font(.caption)
                }
                .foregroundStyle(.primary.opacity(0.72))
            }
        }
    }
}

struct ArtistEventCell_Previews: PreviewProvider {
    static var previews: some View {
        ArtistEventCell(
            event: .example,
            intersectingEvents: [],
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
