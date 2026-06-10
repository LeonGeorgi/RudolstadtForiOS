#if os(iOS)
import SwiftUI

struct SharedFestivalProfileDetailView: View {
    let profile: SharedFestivalProfile

    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject private var currentProfile: FestivalProfileStore

    private var savedEvents: [Event] {
        let savedEventIDs = Set(profile.savedEventIDs)
        return festivalData.events.filter { event in
            savedEventIDs.contains(event.id)
        }
        .sorted(by: compareFriendsEventsByTime)
    }

    private var savedEventGroups: [SharedProfileSavedEventDayGroup] {
        Dictionary(grouping: savedEvents, by: \.festivalDay)
            .map { day, events in
                SharedProfileSavedEventDayGroup(
                    day: day,
                    events: events.sorted(by: compareFriendsEventsByTime)
                )
            }
            .sorted { lhs, rhs in
                lhs.day < rhs.day
            }
    }

    private var ratedArtists: [Artist] {
        let ratedArtistIDs = Set(profile.artistPreferences.map(\.artistID))
        return festivalData.artists.filter { artist in
            ratedArtistIDs.contains(artist.id)
        }
        .sorted { lhs, rhs in
            lhs.formattedName.localizedCaseInsensitiveCompare(rhs.formattedName) == .orderedAscending
        }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    FestivalProfileBadgeAvatar(
                        badge: profile.badge,
                        diameter: 60
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.badge.displayName)
                            .font(.title3.weight(.semibold))
                        Text("friends.detail.subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            if savedEvents.isEmpty {
                Section("friends.detail.saved_events.section") {
                    Text("friends.detail.saved_events.empty")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(savedEventGroups) { group in
                    Section(savedEventDayTitle(for: group.day)) {
                        ForEach(group.events) { event in
                            NavigationLink(
                                value: AppNavigationRoute.artist(
                                    id: event.artist.id,
                                    highlightedEventId: event.id,
                                    transitionSourceID: nil
                                )
                            ) {
                                SharedProfileSavedEventRow(
                                    event: event,
                                    isSavedByCurrentUser: currentProfile.isEventSaved(event.id)
                                )
                            }
                        }
                    }
                }
            }

            Section("friends.detail.artist_ratings.section") {
                if ratedArtists.isEmpty {
                    Text("friends.detail.artist_ratings.empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ratedArtists) { artist in
                        NavigationLink(
                            value: AppNavigationRoute.artist(
                                id: artist.id,
                                highlightedEventId: nil,
                                transitionSourceID: nil
                            )
                        ) {
                            SharedProfileRatedArtistRow(
                                artist: artist,
                                preference: preference(for: artist)
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(profile.badge.displayName)
    }

    private func preference(for artist: Artist) -> FestivalArtistPreference {
        profile.artistPreferences.first { preference in
            preference.artistID == artist.id
        } ?? FestivalArtistPreference(artistID: artist.id, rating: 0, iconName: nil)
    }

    private func savedEventDayTitle(for day: Int) -> String {
        String(
            format: friendsLocalizedString("friends.detail.day_header.format"),
            FestivalDateUtilities.fullWeekDay(day: day),
            Int64(day)
        )
    }
}

private struct SharedProfileSavedEventDayGroup: Identifiable {
    let day: Int
    let events: [Event]

    var id: Int {
        day
    }
}
#endif
