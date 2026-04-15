//
//  ArtistConcertItem.swift
//  RudolstadtForiOS
//
//  Created by Leon on 25.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ArtistEventCell: View {
    let event: Event

    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var dataStore: DataStore

    @State var selectedCollisionArtist: Artist? = nil

    var savedEventIds: [Int] {
        settings.savedEvents
    }

    var eventsThatIntersect: LoadingEntity<[Event]> {
        dataStore.data.map { entities in
            let savedEvents = entities.events.filter {
                savedEventIds.contains($0.id)
            }
            return savedEvents.filter {
                $0.artist.id != event.artist.id
                    && $0.intersects(
                        with: event,
                        event1Duration: dataStore.estimatedEventDurations?[
                            $0.id
                        ] ?? 60,
                        event2Duration: dataStore.estimatedEventDurations?[
                            event.id
                        ] ?? 60
                    )
            }
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            EventTimeBadge(event: event)

            VStack(alignment: .leading, spacing: 3) {
                if let tag = event.tag {
                    Text(tag.localizedName.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                }

                Text(event.stage.localizedName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                intersectingEventsView
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            EventSavedIcon(event: event)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .background(
            NavigationLink(
                isActive: Binding {
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
            } label: {
                EmptyView()
            }
            .hidden()
        )
        .contextMenu {
            if case .success(let intersectingEvents) = eventsThatIntersect {
                ForEach(intersectingEvents) { (intersectingEvent: Event) in
                    Button {
                        self.selectedCollisionArtist = intersectingEvent.artist
                    } label: {
                        Text(intersectingEvent.artist.formattedName)
                        Image(systemName: "exclamationmark.circle")
                    }
                }
            }
            SaveEventButton(event: event)
        }
        .id(settings.idFor(event: event))
    }

    @ViewBuilder
    private var intersectingEventsView: some View {
        switch eventsThatIntersect {
        case .loading:
            Text("events.intersecting.loading")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failure(let reason):
            Text("Failed to load: " + reason.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        case .success(let intersectingEvents):
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
                .foregroundStyle(.orange)
            }
        }
    }
}

private struct EventTimeBadge: View {
    let event: Event

    var body: some View {
        VStack(spacing: 0) {
            Text(event.shortWeekDay.uppercased())
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(.tint.opacity(0.18))

            Text(event.timeAsString)
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.primary)
        .frame(width: 52, height: 52)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(event.shortWeekDay) \(event.timeAsString)"))
    }
}

struct ArtistEventCell_Previews: PreviewProvider {
    static var previews: some View {
        ArtistEventCell(event: .example)
    }
}
