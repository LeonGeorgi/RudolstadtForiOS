import CoreGraphics
import Foundation
import SwiftUI
import Testing

@testable import Rudolstadt

struct ScheduleTimelineZoomTests {
    @Test
    func zoomKeepsAnchorAtSameViewportPosition() {
        let session = makeSession()

        let update = session.update(
            for: ScheduleTimelineZoomMagnification(vertical: 1.5),
            anchorViewportPoint: CGPoint(x: 100, y: 250)
        )

        #expect(update.heightPerHour == 90)
        #expect(update.columnWidth == 70)
        #expect(update.contentOffset.x == 120)
        #expect(abs(update.contentOffset.y - 542.5) < 0.001)
    }

    @Test
    func horizontalZoomKeepsStagePointAtSameViewportPosition() {
        let session = makeSession()

        let update = session.update(
            for: ScheduleTimelineZoomMagnification(horizontal: 1.5),
            anchorViewportPoint: CGPoint(x: 100, y: 250)
        )

        #expect(update.heightPerHour == 60)
        #expect(update.columnWidth == 105)
        #expect(abs(update.contentOffset.x - 195) < 0.001)
        #expect(update.contentOffset.y == 300)
    }

    @Test
    func zoomTracksMovingTouchCentroidAsScrolling() {
        let session = makeSession()

        let update = session.update(
            for: ScheduleTimelineZoomMagnification(vertical: 1.5),
            anchorViewportPoint: CGPoint(x: 80, y: 220)
        )

        #expect(update.contentOffset.x == 140)
        #expect(abs(update.contentOffset.y - 572.5) < 0.001)
    }

    @Test
    func twoFingerScrollingClampsAtHorizontalEdge() {
        let session = makeSession(
            contentOffset: CGPoint(x: 600, y: 300)
        )

        let update = session.update(
            for: ScheduleTimelineZoomMagnification(),
            anchorViewportPoint: CGPoint(x: 50, y: 250)
        )

        #expect(update.contentOffset.x == 610)
    }

    @Test
    func zoomLimitsVerticalScale() {
        let session = makeSession()
        let anchorViewportPoint = CGPoint(x: 100, y: 250)

        #expect(
            session.update(
                for: ScheduleTimelineZoomMagnification(vertical: 0.1),
                anchorViewportPoint: anchorViewportPoint
            ).heightPerHour
                == ScheduleTimelineZoom.minimumHeightPerHour
        )
        #expect(
            session.update(
                for: ScheduleTimelineZoomMagnification(vertical: 3),
                anchorViewportPoint: anchorViewportPoint
            ).heightPerHour
                == ScheduleTimelineZoom.maximumHeightPerHour
        )
    }

    @Test
    func zoomLimitsHorizontalScale() {
        let session = makeSession()
        let anchorViewportPoint = CGPoint(x: 100, y: 250)

        #expect(
            session.update(
                for: ScheduleTimelineZoomMagnification(horizontal: 0.1),
                anchorViewportPoint: anchorViewportPoint
            ).columnWidth == ScheduleTimelineZoom.minimumColumnWidth
        )
        #expect(
            session.update(
                for: ScheduleTimelineZoomMagnification(horizontal: 3),
                anchorViewportPoint: anchorViewportPoint
            ).columnWidth == ScheduleTimelineZoom.maximumColumnWidth
        )
    }

    @Test
    func zoomClampsOffsetAtTopEdge() {
        let session = makeSession(
            contentOffset: CGPoint(x: 40, y: 0),
            anchorViewportY: 100
        )

        let update = session.update(
            for: ScheduleTimelineZoomMagnification(vertical: 0.5),
            anchorViewportPoint: CGPoint(x: 100, y: 100)
        )

        #expect(update.contentOffset == CGPoint(x: 40, y: 0))
    }

    @Test
    func zoomClampsOffsetAtBottomEdge() {
        let session = makeSession(
            contentOffset: CGPoint(x: 40, y: 500),
            anchorViewportY: 600
        )

        let update = session.update(
            for: ScheduleTimelineZoomMagnification(vertical: 0.7),
            anchorViewportPoint: CGPoint(x: 100, y: 600)
        )

        #expect(update.contentOffset.x == 40)
        #expect(abs(update.contentOffset.y - 159.5) < 0.001)
    }

    @Test
    func zoomUpdateIgnoresSubpixelChanges() {
        let reference = ScheduleTimelineZoomUpdate(
            heightPerHour: 60,
            columnWidth: 70,
            contentOffset: CGPoint(x: 20, y: 200)
        )
        let update = ScheduleTimelineZoomUpdate(
            heightPerHour: 60.1,
            columnWidth: 70.1,
            contentOffset: CGPoint(x: 20.1, y: 200.4)
        )

        #expect(!update.isMeaningfullyDifferent(from: reference))
    }

    @Test
    func zoomUpdateAcceptsVisibleScaleOrOffsetChanges() {
        let reference = ScheduleTimelineZoomUpdate(
            heightPerHour: 60,
            columnWidth: 70,
            contentOffset: CGPoint(x: 20, y: 200)
        )
        let scaleUpdate = ScheduleTimelineZoomUpdate(
            heightPerHour: 60.25,
            columnWidth: reference.columnWidth,
            contentOffset: reference.contentOffset
        )
        let columnUpdate = ScheduleTimelineZoomUpdate(
            heightPerHour: reference.heightPerHour,
            columnWidth: 70.25,
            contentOffset: reference.contentOffset
        )
        let offsetUpdate = ScheduleTimelineZoomUpdate(
            heightPerHour: reference.heightPerHour,
            columnWidth: reference.columnWidth,
            contentOffset: CGPoint(x: 20, y: 200.5)
        )

        #expect(scaleUpdate.isMeaningfullyDifferent(from: reference))
        #expect(columnUpdate.isMeaningfullyDifferent(from: reference))
        #expect(offsetUpdate.isMeaningfullyDifferent(from: reference))
    }

    @Test
    func touchGeometryDerivesIndependentAxisMagnification() throws {
        let initial = try #require(
            ScheduleTimelineZoomTouchGeometry(
                firstTouch: CGPoint(x: 0, y: 0),
                secondTouch: CGPoint(x: 80, y: 60)
            )
        )
        let horizontalStretch = try #require(
            ScheduleTimelineZoomTouchGeometry(
                firstTouch: CGPoint(x: -10, y: 0),
                secondTouch: CGPoint(x: 90, y: 60)
            )
        )
        let verticalStretch = try #require(
            ScheduleTimelineZoomTouchGeometry(
                firstTouch: CGPoint(x: 0, y: -10),
                secondTouch: CGPoint(x: 80, y: 70)
            )
        )
        let translatedTouches = try #require(
            ScheduleTimelineZoomTouchGeometry(
                firstTouch: CGPoint(x: 20, y: 30),
                secondTouch: CGPoint(x: 100, y: 90)
            )
        )

        #expect(
            horizontalStretch.magnification(relativeTo: initial)
                == ScheduleTimelineZoomMagnification(
                    horizontal: 1.2
                )
        )
        #expect(
            verticalStretch.magnification(relativeTo: initial)
                == ScheduleTimelineZoomMagnification(
                    vertical: 1.2
                )
        )
        #expect(
            translatedTouches.magnification(relativeTo: initial)
                == ScheduleTimelineZoomMagnification()
        )
    }

    private func makeSession(
        contentOffset: CGPoint = CGPoint(x: 120, y: 300),
        anchorViewportY: CGFloat = 250
    ) -> ScheduleTimelineZoomSession {
        ScheduleTimelineZoomSession(
            baseHeightPerHour: 60,
            baseColumnWidth: 70,
            contentOffset: contentOffset,
            contentSize: CGSize(width: 1_000, height: 1_200),
            containerSize: CGSize(width: 390, height: 700),
            anchorViewportPoint: CGPoint(x: 100, y: anchorViewportY),
            timelineFixedTop: 65,
            horizontalLayout: makeHorizontalLayout()
        )
    }

    private func makeHorizontalLayout() -> ScheduleTimelineHorizontalLayout {
        ScheduleTimelineHorizontalLayout(
            stageCount: 8,
            timeWidth: 55,
            columnSpacing: 5
        )
    }
}

struct ScheduleTimelineEventCellDetailLevelTests {
    @Test
    func cardDetailsGrowAcrossFiveSemanticZoomLevels() {
        #expect(
            ScheduleTimelineEventCellDetailLevel(width: 70, height: 70)
                == .compact
        )
        #expect(
            ScheduleTimelineEventCellDetailLevel(width: 54, height: 84)
                == .time
        )
        #expect(
            ScheduleTimelineEventCellDetailLevel(width: 64, height: 104)
                == .origin
        )
        #expect(
            ScheduleTimelineEventCellDetailLevel(width: 70, height: 148)
                == .discovery
        )
        #expect(
            ScheduleTimelineEventCellDetailLevel(width: 128, height: 168)
                == .summary
        )
    }

    @Test
    func cardDetailsRequireBothHorizontalAndVerticalRoom() {
        #expect(
            ScheduleTimelineEventCellDetailLevel(width: 140, height: 83)
                == .compact
        )
        #expect(
            ScheduleTimelineEventCellDetailLevel(width: 53, height: 240)
                == .compact
        )
        #expect(
            ScheduleTimelineEventCellDetailLevel(width: 127, height: 240)
                == .discovery
        )
        #expect(
            ScheduleTimelineEventCellDetailLevel(width: 140, height: 167)
                == .discovery
        )
    }

    @Test
    func tallNarrowCardsUseTheirVerticalRoomForDetails() {
        #expect(
            ScheduleTimelineEventCellDetailLevel(width: 72, height: 170)
                == .discovery
        )
        #expect(
            ScheduleTimelineEventCellDetailLevel(width: 66, height: 130)
                == .origin
        )
        #expect(
            ScheduleTimelineEventCellDetailLevel(width: 58, height: 100)
                == .time
        )
    }
}

extension ScheduleTimelineZoomTests {
    @Test
    func singleDayZoomKeepsTheConcertUnderTheFingers() {
        let day = ScheduleTimelineDayLayout(hours: 10, headerHeight: 60, viewportHeight: 600)
        let session = ScheduleTimelineZoomSession(
            baseHeightPerHour: 60, baseColumnWidth: 70,
            contentOffset: CGPoint(x: 0, y: 50),
            contentSize: CGSize(width: 400, height: 660),
            containerSize: CGSize(width: 400, height: 600),
            anchorViewportPoint: CGPoint(x: 100, y: 250), timelineFixedTop: 0,
            horizontalLayout: ScheduleTimelineHorizontalLayout(
                stageCount: 4, timeWidth: 55, columnSpacing: 5),
            verticalLayout: day)
        let update = session.update(
            for: .init(vertical: 1.5), anchorViewportPoint: CGPoint(x: 100, y: 250))
        #expect(update.contentOffset.y == 170)
        #expect(update.heightPerHour == 90)
    }
}

@MainActor
struct ScheduleTimelineEventPresentationTests {
    @Test
    func preparesLocalizedLabelsAndKeepsKeywordOrder() {
        let details = ArtistDetails(
            descriptions: FestivalContent(text: LocalizedText(values: [:]), format: .plainText),
            thumbnailURL: nil, imageURL: nil, countryCodes: ["DEU", "DEU"], links: [],
            keywords: [
                LanguageTag("de"): [" Tanz ", "Folk", "Folk", "Akustisch", "Weitere"],
                LanguageTag("en"): ["Dance", "Folk"],
            ])
        let artist = TestFixtures.artist(id: 1).replacing(details: details)
        let event = makeEvent(artist: artist)
        let german = prepare(event, locale: "de_DE")
        let english = prepare(event, locale: "en_US")

        #expect(german.originText == "🇩🇪 Deutschland")
        #expect(english.originText == "🇩🇪 Germany")
        #expect(german.tagsText == "Tanz • Folk • Akustisch")
        #expect(english.tagsText == "Dance • Folk")
        #expect(german.tagText == "Werkstatt")
        #expect(english.tagText == "Workshop")
        #expect(german.timeText == "17:00")
    }

    @Test
    func newSourceAndProfileValuesReplacePresentationWithTheSameIDs() {
        let original = prepare(makeEvent(artist: TestFixtures.artist(id: 1, name: "Original")))
        let updated = prepare(
            makeEvent(artist: TestFixtures.artist(id: 1, name: "Updated")), saved: true, rating: 2)

        #expect(original.event.id == updated.event.id)
        #expect(original.artistName == "Original")
        #expect(updated.artistName == "Updated")
        #expect(!original.contextPreviewState.isSaved)
        #expect(updated.contextPreviewState.isSaved)
        #expect(updated.contextPreviewState.artistRating == 2)
        #expect(original.backgroundColor != updated.backgroundColor)
    }

    @Test
    func savedCardsKeepContrastingTextInBothAppearances() {
        let event = makeEvent(artist: TestFixtures.artist(id: 1))
        let light = prepare(event, saved: true, scheme: .light)
        let dark = prepare(event, saved: true, scheme: .dark)
        #expect(light.foregroundColor == .white)
        #expect(dark.foregroundColor == .black)
        #expect(light.backgroundColor != dark.backgroundColor)
        #expect(prepare(event).ratingHaloColor == .clear)
    }

    private func makeEvent(artist: Artist) -> Event {
        TestFixtures.event(
            id: 1, dayInJuly: 2, timeAsString: "17:00", stage: TestFixtures.stage(id: 1),
            artist: artist, tag: Tag(id: 99, germanName: "Werkstatt", englishName: "Workshop"))
    }

    private func prepare(
        _ event: Event, locale: String = "de_DE", saved: Bool = false, rating: Int = 0,
        scheme: ColorScheme = .light
    ) -> ScheduleTimelineEventPresentation {
        let locale = Locale(identifier: locale)
        let formatter = ListFormatter()
        formatter.locale = locale
        return ScheduleTimelineEventPresentation(
            event: event, duration: 60,
            contextPreviewState: EventContextPreviewState(
                isSaved: saved, artistRating: rating, artistIconName: nil,
                friendProfilesWhoSavedEvent: [], artistNote: nil, isArtistSummaryEnabled: true),
            locale: locale, colorScheme: scheme, countryFormatter: formatter)
    }
}
