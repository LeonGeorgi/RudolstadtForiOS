#if os(iOS)
import SwiftUI
import Testing
@testable import Rudolstadt

@MainActor
struct FriendArtistRatingsMotionTests {
    private typealias Motion = FriendArtistRatingsMotion

    @Test(arguments: [1, 3, 7])
    func friendButtonHasItsOwnLayoutSpaceAboveTheRatingButton(count: Int) {
        let settings = TestFixtures.userSettings()
        let profile = TestFixtures.festivalProfileStore()
        let artist = TestFixtures.artist(id: 1)
        let friends = FriendProfilesStore()
        let button = ArtistRatingPopoverButton(artist: artist, currentTipID: nil)
            .environmentObject(settings)
            .environmentObject(profile)
            .environmentObject(friends)
        let host = UIHostingController(rootView: button)
        let proposal = CGSize(width: 393, height: 852)
        let withoutFriends = host.sizeThatFits(in: proposal)

        friends.updateProfiles((0..<count).map { index in
            TestFixtures.sharedFestivalProfile(
                id: "friend-\(index)",
                artistPreferences: [.init(artistID: artist.id, rating: 2, iconName: nil)]
            )
        })
        let withFriends = UIHostingController(rootView: button).sizeThatFits(in: proposal)

        #expect(withoutFriends.height == 50)
        #expect(withFriends.height >= withoutFriends.height + 56 + 12)
        #expect(withFriends.width >= 56)
    }

    @Test(arguments: 0...7)
    func summaryShowsUpToThreeFriendsBeforeAddingOverflow(count: Int) {
        let summary = FriendArtistRatingSummary(entries: (0..<count).map { index in
            .init(
                profileID: "friend-\(index)",
                badge: FestivalProfileBadge(displayName: "Friend \(index)", colorHex: "#23867A"),
                preference: FestivalArtistPreference(artistID: 1, rating: 2, iconName: nil)
            )
        })
        #expect(summary.visibleEntries.count == min(count, 3))
        #expect(summary.remainingCount == max(0, count - 3))
        #expect(summary.visibleEntries.map(\.id) == Array(summary.entries.prefix(3)).map(\.id))
    }

    @Test
    func openingLeadsTheFollowingBadgesAndSettlesTogether() {
        let timeline = KeyframeTimeline(initialValue: Motion.Values()) {
            Motion.Frames(opening: true, initial: .init())
        }
        let pulling = timeline.value(time: 0.15)
        #expect(pulling.first > pulling.second)
        #expect(pulling.second > pulling.third)
        #expect(pulling.third > 0)
        #expect(timeline.duration < 0.8)
        let end = timeline.value(time: timeline.duration)
        #expect(abs(end.first - 1) < 0.0001)
        #expect(abs(end.second - 1) < 0.0001)
        #expect(abs(end.third - 1) < 0.0001)
    }

    @Test
    func closingRetractsFromTheTailAndReturnsToTheSource() {
        let timeline = KeyframeTimeline(initialValue: Motion.Values.expanded) {
            Motion.Frames(opening: false, initial: .expanded)
        }
        let retracting = timeline.value(time: 0.15)
        #expect(retracting.third < retracting.second)
        #expect(retracting.second < retracting.first)
        let end = timeline.value(time: timeline.duration)
        #expect(abs(end.first) < 0.0001)
        #expect(abs(end.second) < 0.0001)
        #expect(abs(end.third) < 0.0001)
    }

    @Test
    func earlyDismissalContinuesFromTheCurrentPositions() {
        let current = Motion.openingValue(at: 0.16)
        #expect(current.first > current.second)
        #expect(current.first < 1)
        let timeline = KeyframeTimeline(initialValue: current) {
            Motion.Frames(opening: false, initial: current)
        }
        let start = timeline.value(time: 0)
        #expect(start.first == current.first)
        #expect(start.second == current.second)
        #expect(start.third == current.third)
        let end = timeline.value(time: timeline.duration)
        #expect(abs(end.first) < 0.0001)
        #expect(abs(end.second) < 0.0001)
        #expect(abs(end.third) < 0.0001)
    }

    @Test(arguments: 0..<3)
    func pathsHaveExactEndpointsAndStartMostlyHorizontally(index: Int) {
        let start = CGPoint(x: 314 + index * 20, y: 314)
        let end = CGPoint(x: 64, y: 359 + index * 60)
        #expect(Motion.point(from: start, to: end, index: index, progress: 0) == start)
        #expect(Motion.point(from: start, to: end, index: index, progress: 1) == end)
        let departing = Motion.point(from: start, to: end, index: index, progress: 0.01)
        #expect(departing.x < start.x)
        #expect(departing.y > start.y)
        #expect(abs(departing.x - start.x) > abs(departing.y - start.y))
    }
}
#endif
