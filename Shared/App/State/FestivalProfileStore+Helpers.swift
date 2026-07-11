import Foundation

extension FestivalProfileStore {
    func profileTransitionSummary(
        from oldProfile: CachedOwnerFestivalProfile,
        to newProfile: CachedOwnerFestivalProfile
    ) -> String {
        let addedEventCount = Set(newProfile.savedEventIDs).subtracting(oldProfile.savedEventIDs).count
        let removedEventCount = Set(oldProfile.savedEventIDs).subtracting(newProfile.savedEventIDs).count

        let oldPreferences = Dictionary(
            uniqueKeysWithValues: oldProfile.artistPreferences.map { preference in
                (preference.artistID, preference)
            }
        )
        let newPreferences = Dictionary(
            uniqueKeysWithValues: newProfile.artistPreferences.map { preference in
                (preference.artistID, preference)
            }
        )
        let changedPreferenceCount = newPreferences.filter { artistID, preference in
            oldPreferences[artistID] != preference
        }.count
        let removedPreferenceCount = Set(oldPreferences.keys).subtracting(newPreferences.keys).count

        let oldNotes = Dictionary(
            uniqueKeysWithValues: oldProfile.artistNotes.map { note in
                (note.artistID, note)
            }
        )
        let newNotes = Dictionary(
            uniqueKeysWithValues: newProfile.artistNotes.map { note in
                (note.artistID, note)
            }
        )
        let changedNoteCount = newNotes.filter { artistID, note in
            oldNotes[artistID] != note
        }.count
        let removedNoteCount = Set(oldNotes.keys).subtracting(newNotes.keys).count

        let badgeChanged = oldProfile.badgeName != newProfile.badgeName
            || FestivalProfileBadge.resolvedColorHex(oldProfile.badgeColorHex)
                != FestivalProfileBadge.resolvedColorHex(newProfile.badgeColorHex)

        return "events +\(addedEventCount)/-\(removedEventCount), preferences changed=\(changedPreferenceCount) removed=\(removedPreferenceCount), notes changed=\(changedNoteCount) removed=\(removedNoteCount), badge changed=\(badgeChanged)"
    }

    static func artistPreferencesDictionary(
        from preferences: [FestivalArtistPreference]
    ) -> [String: FestivalArtistPreference] {
        Dictionary(
            uniqueKeysWithValues: preferences.map { preference in
                (String(preference.artistID), preference)
            }
        )
    }

    static func makeSharedProfile(
        from cachedProfile: CachedSharedFestivalProfile
    ) -> SharedFestivalProfile {
        SharedFestivalProfile(
            id: cachedProfile.id,
            title: cachedProfile.title,
            ownerName: cachedProfile.ownerName,
            badgeName: cachedProfile.badgeName,
            badgeColorHex: cachedProfile.badgeColorHex,
            festivalYear: cachedProfile.festivalYear,
            savedEventIDs: cachedProfile.savedEventIDs.sorted(),
            artistPreferences: cachedProfile.artistPreferences
                .sorted { lhs, rhs in
                    lhs.artistID < rhs.artistID
                }
        )
    }
}
