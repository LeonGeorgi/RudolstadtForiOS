#if os(iOS)
import SwiftUI
import Testing
import UIKit
@testable import Rudolstadt

@MainActor
struct FriendRecommendationArtworkTests {
    @Test
    func colorsComeFromTheBottomRatherThanTheTopOfThePhoto() throws {
        let image = makeImage(width: 100, height: 100) { context in
            context.setFillColor(UIColor.blue.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            context.setFillColor(UIColor.red.cgColor)
            context.fill(CGRect(x: 0, y: 75, width: 100, height: 25))
        }
        let colors = try #require(FriendRecommendationArtworkColors(image: image))
        for color in colors.upper + colors.lower {
            #expect(color.x > 0.99)
            #expect(color.y < 0.01 && color.z < 0.01)
        }
    }

    @Test
    func colorsUseTheVisibleSquareCrop() throws {
        let image = makeImage(width: 300, height: 100) { context in
            context.setFillColor(UIColor.green.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 100))
            context.setFillColor(UIColor.red.cgColor)
            context.fill(CGRect(x: 100, y: 0, width: 100, height: 100))
        }
        let colors = try #require(FriendRecommendationArtworkColors(image: image))
        #expect(colors.upper.allSatisfy { $0.x > 0.98 && $0.y < 0.02 })
        #expect(colors.lower.allSatisfy { $0.x > 0.98 && $0.y < 0.02 })
    }

    @Test
    func cameraOrientationIsAppliedBeforeSampling() throws {
        let image = makeImage(width: 100, height: 100) { context in
            context.setFillColor(UIColor.blue.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            context.setFillColor(UIColor.red.cgColor)
            context.fill(CGRect(x: 0, y: 75, width: 100, height: 25))
        }
        let cgImage = try #require(image.cgImage)
        let rotated = UIImage(cgImage: cgImage, scale: 1, orientation: .down)
        let colors = try #require(FriendRecommendationArtworkColors(image: rotated))
        #expect(colors.lower.allSatisfy { $0.z > 0.99 && $0.x < 0.01 })
    }

    @Test
    func horizontalColorsRemainDistinctAndMixMoreTowardTheBottom() throws {
        let image = makeImage(width: 100, height: 100) { context in
            context.setFillColor(UIColor.red.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 50, height: 100))
            context.setFillColor(UIColor.blue.cgColor)
            context.fill(CGRect(x: 50, y: 0, width: 50, height: 100))
        }
        let colors = try #require(FriendRecommendationArtworkColors(image: image))
        #expect(try #require(colors.upper.first).x > 0.99)
        #expect(try #require(colors.upper.last).z > 0.99)
        #expect(colors.lower[16].z > colors.upper[16].z + 0.05)
        #expect(colors.lower[24].x > colors.upper[24].x + 0.05)
    }

    @Test
    func missingImageLeavesTheFallbackAvailable() {
        #expect(FriendRecommendationArtworkColors(image: UIImage()) == nil)
    }

    @Test(arguments: [1, 2])
    func cardUsesTwoLinesAndGrowsForAccessibilityText(contributionCount: Int) {
        let artist = TestFixtures.artist(id: 42, name: "Duo Ruut")
        let badge = FestivalProfileBadge(displayName: "Anna", hue: 165)
        let event = TestFixtures.event(id: 1, dayInJuly: 3, timeAsString: "18:00",
                                       stage: TestFixtures.stage(id: 1), artist: artist)
        let contributions: [FriendArtistRecommendation.Contribution] = [
            .init(profileID: "anna", badge: badge, kind: .savedEvent(event), score: 1),
            .init(profileID: "max", badge: badge,
                  kind: .rating(.init(artistID: artist.id, rating: 3, iconName: nil)), score: 1)
        ]
        let recommendation = FriendArtistRecommendation(
            artist: artist, contributions: Array(contributions.prefix(contributionCount)), score: 2
        )
        let tile = FriendArtistRecommendationTile(recommendation: recommendation)
            .environmentObject(TestFixtures.userSettings())
        let proposal = CGSize(width: 240, height: 2_000)
        let regular = UIHostingController(rootView: tile.dynamicTypeSize(.large))
            .sizeThatFits(in: proposal)
        let accessible = UIHostingController(rootView: tile.dynamicTypeSize(.accessibility5))
            .sizeThatFits(in: proposal)
        #expect(abs(regular.height - 304) < 1)
        #expect(accessible.height > regular.height)
        #expect(accessible.width <= 240)
    }

    private func makeImage(
        width: CGFloat, height: CGFloat, draw: (CGContext) -> Void
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            .image { draw($0.cgContext) }
    }
}

@MainActor
struct FriendRecommendationGridTests {
    @Test
    func cardsFollowTheShorterColumnWithoutSharingRowHeights() {
        let frames = FriendRecommendationGridLayout().frames(
            width: 362, heights: [281, 251, 301, 251]
        )
        #expect(frames == [
            CGRect(x: 0, y: 0, width: 175, height: 281),
            CGRect(x: 187, y: 0, width: 175, height: 251),
            CGRect(x: 187, y: 263, width: 175, height: 301),
            CGRect(x: 0, y: 293, width: 175, height: 251)
        ])
    }

    @Test
    func accessibilityColumnKeepsTheRecommendationOrder() {
        let frames = FriendRecommendationGridLayout(columnCount: 1).frames(
            width: 362, heights: [281, 251, 301]
        )
        #expect(frames == [
            CGRect(x: 0, y: 0, width: 362, height: 281),
            CGRect(x: 0, y: 293, width: 362, height: 251),
            CGRect(x: 0, y: 556, width: 362, height: 301)
        ])
        #expect(FriendRecommendationGridLayout().frames(width: 362, heights: []).isEmpty)
    }

    @Test
    func anotherFriendActivityAddsATextRowRatherThanChangingTheImageSize() {
        let oneActivity = measuredCard(contributionCount: 1)
        let twoActivities = measuredCard(contributionCount: 2)
        #expect(abs(oneActivity.width - 175) < 1)
        #expect(abs(twoActivities.width - 175) < 1)
        #expect(oneActivity.height > 175)
        #expect(abs(twoActivities.height - oneActivity.height - 30) < 1)
    }

    @Test
    func longNamesAndAccessibleTextGrowTheCardWithoutClipping() {
        let regular = measuredCard(contributionCount: 2)
        let longName = measuredCard(
            contributionCount: 2, name: "Ein sehr langer mehrzeiliger Künstlername"
        )
        let accessible = measuredCard(contributionCount: 2, dynamicTypeSize: .accessibility5)
        #expect(longName.height > regular.height)
        #expect(accessible.height > regular.height)
        #expect(accessible.width <= 175)
    }

    private func measuredCard(
        contributionCount: Int, name: String = "Duo Ruut", dynamicTypeSize: DynamicTypeSize = .large
    ) -> CGSize {
        let artist = TestFixtures.artist(id: 42, name: name)
        let badge = FestivalProfileBadge(displayName: "Anna", hue: 165)
        let event = TestFixtures.event(
            id: 1, dayInJuly: 3, timeAsString: "18:00",
            stage: TestFixtures.stage(id: 1), artist: artist
        )
        let contributions: [FriendArtistRecommendation.Contribution] = [
            .init(profileID: "anna", badge: badge, kind: .savedEvent(event), score: 1),
            .init(profileID: "max", badge: badge,
                  kind: .rating(.init(artistID: artist.id, rating: 3, iconName: nil)), score: 1)
        ]
        let tile = FriendArtistRecommendationCard(recommendation: .init(
            artist: artist, contributions: Array(contributions.prefix(contributionCount)), score: 2
        ))
        .environmentObject(TestFixtures.userSettings())
        .dynamicTypeSize(dynamicTypeSize)
        return UIHostingController(rootView: tile).sizeThatFits(
            in: CGSize(width: 175, height: 2_000)
        )
    }
}
#endif
