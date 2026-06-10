import Foundation

extension FestivalProfileStore {
    func normalized(
        currentProfile: CachedOwnerFestivalProfile
    ) -> CachedOwnerFestivalProfile {
        var normalizedProfile = currentProfile
        normalizedProfile.badgeName = FestivalProfileBadge.normalizedName(normalizedProfile.badgeName)
        normalizedProfile.badgeColorHex = FestivalProfileBadge.resolvedColorHex(
            normalizedProfile.badgeColorHex
        )
        normalizedProfile.savedEventIDs = Array(Set(currentProfile.savedEventIDs)).sorted()
        normalizedProfile.artistPreferences = Array(
            Dictionary(
                uniqueKeysWithValues: currentProfile.artistPreferences.map { preference in
                    (preference.artistID, preference)
                }
            )
            .values
        )
        .sorted { lhs, rhs in
            lhs.artistID < rhs.artistID
        }
        normalizedProfile.artistNotes = Array(
            Dictionary(
                uniqueKeysWithValues: currentProfile.artistNotes.map { note in
                    (note.artistID, note)
                }
            )
            .values
        )
        .sorted { lhs, rhs in
            lhs.artistID < rhs.artistID
        }
        return normalizedProfile
    }

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

    static func loadCache(from userDefaults: UserDefaults) -> FestivalProfileCache? {
        guard let cachedData = userDefaults.data(forKey: Constants.cacheKey) else {
            return nil
        }
        return try? JSONDecoder().decode(FestivalProfileCache.self, from: cachedData)
    }

    static func loadLegacyOwnerProfile(
        from userDefaults: UserDefaults
    ) -> CachedOwnerFestivalProfile {
        let savedEventIDs = (userDefaults.array(forKey: Constants.legacySavedEventsKey) as? [Int] ?? [])
            .sorted()
        let ratings = userDefaults.dictionary(forKey: Constants.legacyRatingsKey) as? [String: Int] ?? [:]
        let icons = userDefaults.dictionary(forKey: Constants.legacyArtistIconsKey) as? [String: String] ?? [:]
        let notes = userDefaults.dictionary(forKey: Constants.legacyArtistNotesKey) as? [String: String] ?? [:]

        let preferences = ratings.compactMap { entry -> FestivalArtistPreference? in
            guard let artistID = Int(entry.key) else {
                return nil
            }
            return FestivalArtistPreference(
                artistID: artistID,
                rating: entry.value,
                iconName: icons[entry.key]
            )
        }
        .sorted { lhs, rhs in
            lhs.artistID < rhs.artistID
        }

        let artistNotes = notes.compactMap { entry -> FestivalArtistNote? in
            guard let artistID = Int(entry.key) else {
                return nil
            }
            return FestivalArtistNote(artistID: artistID, noteText: entry.value)
        }
        .sorted { lhs, rhs in
            lhs.artistID < rhs.artistID
        }

        return CachedOwnerFestivalProfile(
            festivalYear: DataStore.year,
            badgeName: nil,
            badgeColorHex: FestivalProfileBadge.defaultColorHex,
            savedEventIDs: savedEventIDs,
            artistPreferences: preferences,
            artistNotes: artistNotes,
            shareRecordName: nil,
            shareRecordSystemFieldsData: nil,
            rootRecordSystemFieldsData: nil,
            savedEventRecordSystemFieldsByName: [:],
            artistPreferenceRecordSystemFieldsByName: [:],
            artistNoteRecordSystemFieldsByName: [:]
        )
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
