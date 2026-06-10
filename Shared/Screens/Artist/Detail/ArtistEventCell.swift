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
    let isSaved: Bool
    var friendProfilesWhoSavedEvent: [SharedFestivalProfile] = []
    let onToggleSaved: () -> Void
    @Environment(\.artistNavigationHandler) private var navigate

    @State var selectedCollisionArtist: Artist? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            EventTimeBadge(event: event)

            VStack(alignment: .leading, spacing: 3) {
                if let tag = event.tag {
                    Text(tag.localizedName.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.72))
                        .lineLimit(1)
                }

                Text(event.stage.localizedName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                intersectingEventsView
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !friendProfilesWhoSavedEvent.isEmpty {
                FriendSavedEventBadges(
                    eventID: event.id,
                    profiles: friendProfilesWhoSavedEvent,
                    style: .plainInline
                )
                .frame(minWidth: 24, minHeight: 24, alignment: .center)
            }

            EventSavedIcon(event: event, isSaved: isSaved, onToggle: onToggleSaved)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
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
            } else {
                EmptyView()
            }
        }
        .contextMenu {
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
                    Text(intersectingEvent.artist.formattedName)
                    Image(systemName: "exclamationmark.circle")
                }
            }
            SaveEventButton(event: event, isSaved: isSaved, onToggle: onToggleSaved)
        }
        .id("\(event.id)-\(isSaved)")
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
            isSaved: false,
            onToggleSaved: {}
        )
    }
}
