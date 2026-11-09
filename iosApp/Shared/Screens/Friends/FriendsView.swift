#if os(iOS)
import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var friends: FriendProfilesStore
    @EnvironmentObject private var profile: FestivalProfileStore
    @Environment(\.firebaseAccountProfile) private var accountProfile
    @Environment(\.festivalEdition) private var edition

    var body: some View {
        if let accountProfile {
            FirebaseFriendsView(accountProfile: accountProfile, sync: profile.firebaseOwnProfile)
        } else {
            List {
                if edition.isExperimental {
                    Text("festival.experimental.sharing_unavailable")
                } else {
                    Text("firebase.friends.unavailable")
                }
                ForEach(sortedFriendProfiles(friends.state.profiles)) { friend in
                    NavigationLink(value: AppNavigationRoute.sharedFestivalProfile(profile: friend)) {
                        Text(friend.title)
                    }
                }
            }
            .navigationTitle("more.friends.title")
        }
    }
}
#endif
