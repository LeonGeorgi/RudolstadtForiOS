import Foundation

enum FestivalProfileMutation: Equatable, Sendable {
    case toggleSavedEvent(eventID: Int)
    case updateBadge(name: String, colorHex: String)
    case setArtistRating(artistID: Int, rating: Int)
    case setArtistIcon(artistID: Int, iconName: String)
    case setArtistNote(artistID: Int, noteText: String)
}

enum FestivalProfileReducer {
    static func applying(
        _ mutation: FestivalProfileMutation,
        to profile: CachedOwnerFestivalProfile
    ) -> CachedOwnerFestivalProfile {
        var profile = profile

        switch mutation {
        case .toggleSavedEvent(let eventID):
            var savedEventIDs = Set(profile.savedEventIDs)
            if savedEventIDs.contains(eventID) {
                savedEventIDs.remove(eventID)
            } else {
                savedEventIDs.insert(eventID)
            }
            profile.savedEventIDs = Array(savedEventIDs)

        case .updateBadge(let name, let colorHex):
            profile.badgeName = FestivalProfileBadge.normalizedName(name)
            profile.badgeColorHex = FestivalProfileBadge.resolvedColorHex(colorHex)

        case .setArtistRating(let artistID, let rating):
            var preferences = preferencesByArtistID(profile.artistPreferences)
            if rating == 0 {
                preferences.removeValue(forKey: artistID)
            } else {
                var preference = preferences[artistID] ?? FestivalArtistPreference(
                    artistID: artistID,
                    rating: rating,
                    iconName: nil
                )
                preference.rating = rating
                if rating > 0 {
                    preference.iconName = nil
                }
                preferences[artistID] = preference
            }
            profile.artistPreferences = Array(preferences.values)

        case .setArtistIcon(let artistID, let iconName):
            var preferences = preferencesByArtistID(profile.artistPreferences)
            preferences[artistID] = FestivalArtistPreference(
                artistID: artistID,
                rating: -1,
                iconName: iconName
            )
            profile.artistPreferences = Array(preferences.values)

        case .setArtistNote(let artistID, let noteText):
            let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            var notes = Dictionary(
                uniqueKeysWithValues: profile.artistNotes.map { note in
                    (note.artistID, note)
                }
            )
            if trimmedNote.isEmpty {
                notes.removeValue(forKey: artistID)
            } else {
                notes[artistID] = FestivalArtistNote(
                    artistID: artistID,
                    noteText: trimmedNote
                )
            }
            profile.artistNotes = Array(notes.values)
        }

        return normalized(profile)
    }

    static func normalized(
        _ profile: CachedOwnerFestivalProfile
    ) -> CachedOwnerFestivalProfile {
        var normalizedProfile = profile
        normalizedProfile.badgeName = FestivalProfileBadge.normalizedName(profile.badgeName)
        normalizedProfile.badgeColorHex = FestivalProfileBadge.resolvedColorHex(
            profile.badgeColorHex
        )
        normalizedProfile.savedEventIDs = Array(Set(profile.savedEventIDs)).sorted()
        normalizedProfile.artistPreferences = Array(
            preferencesByArtistID(profile.artistPreferences).values
        )
        .sorted { lhs, rhs in
            lhs.artistID < rhs.artistID
        }
        normalizedProfile.artistNotes = Array(
            Dictionary(
                uniqueKeysWithValues: profile.artistNotes.map { note in
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

    private static func preferencesByArtistID(
        _ preferences: [FestivalArtistPreference]
    ) -> [Int: FestivalArtistPreference] {
        Dictionary(
            uniqueKeysWithValues: preferences.map { preference in
                (preference.artistID, preference)
            }
        )
    }
}

enum FestivalProfileSyncRecord: Equatable, Hashable, Sendable {
    case profile
    case savedEvent(eventID: Int)
    case artistPreference(artistID: Int)
    case artistNote(artistID: Int)
}

enum FestivalProfileSyncChange: Equatable, Sendable {
    case save(FestivalProfileSyncRecord)
    case delete(FestivalProfileSyncRecord)
}

enum FestivalProfileSyncPlanner {
    static func changes(
        from oldProfile: CachedOwnerFestivalProfile,
        to newProfile: CachedOwnerFestivalProfile
    ) -> [FestivalProfileSyncChange] {
        var changes: [FestivalProfileSyncChange] = [.save(.profile)]

        let oldSavedEventIDs = Set(oldProfile.savedEventIDs)
        let newSavedEventIDs = Set(newProfile.savedEventIDs)
        changes += newSavedEventIDs.subtracting(oldSavedEventIDs)
            .sorted()
            .map { .save(.savedEvent(eventID: $0)) }
        changes += oldSavedEventIDs.subtracting(newSavedEventIDs)
            .sorted()
            .map { .delete(.savedEvent(eventID: $0)) }

        let oldPreferences = Dictionary(
            uniqueKeysWithValues: oldProfile.artistPreferences.map { ($0.artistID, $0) }
        )
        let newPreferences = Dictionary(
            uniqueKeysWithValues: newProfile.artistPreferences.map { ($0.artistID, $0) }
        )
        changes += newPreferences
            .filter { oldPreferences[$0.key] != $0.value }
            .keys
            .sorted()
            .map { .save(.artistPreference(artistID: $0)) }
        changes += Set(oldPreferences.keys).subtracting(newPreferences.keys)
            .sorted()
            .map { .delete(.artistPreference(artistID: $0)) }

        let oldNotes = Dictionary(
            uniqueKeysWithValues: oldProfile.artistNotes.map { ($0.artistID, $0) }
        )
        let newNotes = Dictionary(
            uniqueKeysWithValues: newProfile.artistNotes.map { ($0.artistID, $0) }
        )
        changes += newNotes
            .filter { oldNotes[$0.key] != $0.value }
            .keys
            .sorted()
            .map { .save(.artistNote(artistID: $0)) }
        changes += Set(oldNotes.keys).subtracting(newNotes.keys)
            .sorted()
            .map { .delete(.artistNote(artistID: $0)) }

        return changes
    }

    static func fullUpload(
        for profile: CachedOwnerFestivalProfile
    ) -> [FestivalProfileSyncChange] {
        var changes: [FestivalProfileSyncChange] = [.save(.profile)]
        changes += profile.savedEventIDs.sorted().map { .save(.savedEvent(eventID: $0)) }
        changes += profile.artistPreferences
            .sorted { $0.artistID < $1.artistID }
            .map { .save(.artistPreference(artistID: $0.artistID)) }
        changes += profile.artistNotes
            .sorted { $0.artistID < $1.artistID }
            .map { .save(.artistNote(artistID: $0.artistID)) }
        return changes
    }
}
