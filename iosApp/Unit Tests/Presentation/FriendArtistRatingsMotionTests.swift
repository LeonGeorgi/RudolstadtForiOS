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

        friends.viewModel.restore(profiles: (0..<count).map { index in
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
                badge: FestivalProfileBadge(displayName: "Friend \(index)", hue: 165),
                preference: FestivalArtistPreference(artistID: 1, rating: 2, iconName: nil)
            )
        })
        #expect(summary.visibleEntries.count == min(count, 3))
        #expect(summary.remainingCount == max(0, count - 3))
        #expect(summary.visibleEntries.map(\.id) == Array(summary.entries.prefix(3)).map(\.id))
    }

    @Test(arguments: [1, 2, 3, 4, 7])
    func badgesStartAndLandInStaggeredOrder(friendCount: Int) {
        let duration = Motion.duration(forFriendCount: friendCount)
        let expectedMilliseconds = [300, 350, 400, 450][min(friendCount, 4) - 1]
        #expect(Int((duration * 1000).rounded()) == expectedMilliseconds)
        for index in 0..<min(friendCount, 3) {
            let departure = Double(index * 50) / 1000
            let arrival = Double(300 + index * 50) / 1000
            #expect(Motion.badgeProgress(at: departure, index: index) == 0)
            #expect(Motion.badgeProgress(at: departure + 0.01, index: index) > 0)
            #expect(Motion.badgeProgress(at: arrival - 0.01, index: index) < 1)
            #expect(Motion.badgeProgress(at: arrival, index: index) == 1)
        }
        let start = ContinuousClock.now
        let opening = Motion.Flight(start: start, from: 0, to: duration)
        let closing = Motion.Flight(start: start, from: duration, to: 0)
        #expect(opening.deadline == closing.deadline)
        #expect(opening.playhead(at: opening.deadline) == duration)
        #expect(closing.playhead(at: closing.deadline) == 0)
    }

    @Test
    func closingReversesTheSamePlayheadIncludingWhenInterrupted() {
        let start = ContinuousClock.now
        let duration = Motion.duration(forFriendCount: 4)
        let opening = Motion.Flight(start: start, from: 0, to: duration)
        let interruptedAt = start.advanced(by: .milliseconds(210))
        let current = opening.playhead(at: interruptedAt)
        let earlyClose = Motion.Flight(start: interruptedAt, from: current, to: 0)
        #expect(earlyClose.playhead(at: interruptedAt) == current)
        #expect(abs(earlyClose.playhead(at: interruptedAt.advanced(by: .milliseconds(30))) - 0.18) < 0.0001)
        #expect(earlyClose.playhead(at: earlyClose.deadline) == 0)

        let closing = Motion.Flight(start: start, from: duration, to: 0)
        #expect(abs(start.duration(to: closing.deadline) / .seconds(1) - 0.45) < 0.0001)
        #expect(closing.playhead(at: closing.deadline) == 0)
    }

    @Test(arguments: [1, 4, 16])
    func theCounterSplitsInFlightAndTheWholeFanFitsInTheTimeline(count: Int) {
        let split = Motion.counter(at: 0.26)
        #expect(split.progress > 0 && split.progress < 0.9)
        #expect(split.opacity > 0 && split.opacity < 1)
        #expect(Motion.fan(at: 0.26, index: 0, count: count).spread > 0)
        #expect(Motion.counter(at: 0).opacity == 1)
        #expect(Motion.fan(at: 0, index: 0, count: count).opacity == 0)
        #expect(Motion.counter(at: 0.40).opacity == 0)
        #expect(Motion.counter(at: 0.40).progress < 1)
        let stillFanning = Motion.fan(at: 0.40, index: count - 1, count: count)
        #expect(stillFanning.spread > 0 && stillFanning.spread < 1)
        let last = Motion.fan(at: 0.45, index: count - 1, count: count)
        #expect(last.spread == 1 && last.opacity == 1)
    }

    @Test
    func sharedControlPointIncludesOverflowDestinationsInItsVerticalSpan() {
        let control = Motion.controlPoint(
            from: CGPoint(x: 334, y: 314),
            to: CGPoint(x: 64, y: 419),
            targetHeights: [359, 419, 479, 560, 659]
        )
        #expect(abs(control.x - 153.1) < 0.0001)
        #expect(control.y == 509)
    }

    @Test
    func badgesFollowAQuadraticPathThroughTheSharedControlGeometry() {
        let start = CGPoint(x: 300, y: 100)
        let end = CGPoint(x: 100, y: 200)
        let control = CGPoint(x: 160, y: 260)
        #expect(Motion.point(from: start, to: end, control: control, progress: 0) == start)
        #expect(Motion.point(from: start, to: end, control: control, progress: 0.5) == CGPoint(x: 180, y: 205))
        #expect(Motion.point(from: start, to: end, control: control, progress: 1) == end)
    }
}
#endif
