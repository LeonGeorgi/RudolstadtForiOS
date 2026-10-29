import Foundation

extension FestivalProfileStore {
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
        cachedProfile.domain
    }
}
