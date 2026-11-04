import RudolstadtCore
import Testing
@testable import Rudolstadt

struct SchedulePresenterTests {
    @Test
    func optimalFilterShowsSavedAndRecommendedEvents() {
        let events = makeEvents(startingAt: 801, count: 3)
        let presenter = SchedulePresenter(
            festivalData: TestFixtures.festivalData(events: events),
            recommendationState: TestFixtures.recommendationState([802]),
            scheduleFilterType: .optimal,
            profileState: TestFixtures.profileState(saved: [801], positive: []),
            calendar: TestFixtures.festivalCalendar
        )

        guard case .success(let shownEvents) = presenter.shownEvents else {
            Issue.record("Expected shown events")
            return
        }
        #expect(shownEvents.map(\.id) == [801, 802])
    }

    @Test
    func interestingFilterShowsSavedAndPositiveRatedArtists() {
        let events = makeEvents(startingAt: 811, count: 3)
        let presenter = SchedulePresenter(
            festivalData: TestFixtures.festivalData(events: events),
            recommendationState: TestFixtures.recommendationState(),
            scheduleFilterType: .interesting,
            profileState: TestFixtures.profileState(saved: [811], positive: [812]),
            calendar: TestFixtures.festivalCalendar
        )

        guard case .success(let shownEvents) = presenter.shownEvents else {
            Issue.record("Expected shown events")
            return
        }
        #expect(shownEvents.map(\.id) == [811, 812])
    }

    @Test
    func savedFilterShowsOnlySavedEvents() {
        let events = makeEvents(startingAt: 821, count: 2)
        let presenter = SchedulePresenter(
            festivalData: TestFixtures.festivalData(events: events),
            recommendationState: TestFixtures.recommendationState(),
            scheduleFilterType: .saved,
            profileState: TestFixtures.profileState(saved: [822], positive: []),
            calendar: TestFixtures.festivalCalendar
        )

        guard case .success(let shownEvents) = presenter.shownEvents else {
            Issue.record("Expected shown events")
            return
        }
        #expect(shownEvents.map(\.id) == [822])
    }

    @Test
    func allFilterShowsAllEvents() {
        let events = makeEvents(startingAt: 831, count: 2)
        let presenter = SchedulePresenter(
            festivalData: TestFixtures.festivalData(events: events),
            recommendationState: TestFixtures.recommendationState(),
            scheduleFilterType: .all,
            profileState: TestFixtures.profileState(saved: [], positive: []),
            calendar: TestFixtures.festivalCalendar
        )

        guard case .success(let shownEvents) = presenter.shownEvents else {
            Issue.record("Expected shown events")
            return
        }
        #expect(shownEvents.map(\.id) == [831, 832])
    }

    @Test
    func personalTimelineUsesTheSavedEventsWithoutRemovingEarlierConcerts() {
        let events = makeEvents(startingAt: 841, count: 3)
        let data = TestFixtures.festivalData(events: events)
        let entries = PlanDayTimeline.shared.entries(
            events: Array(events.reversed()), transfer: data.coreWalkingTransfers)

        #expect(entries.map(\.event).map(\.id) == [841, 842, 843])
        #expect(entries.allSatisfy { !$0.hasDashedConnectorBefore })
    }

    @Test
    func personalTimelineOnlyMarksTheConcertWithAnEarlierCollision() {
        let first = TestFixtures.event(
            id: 851, dayInJuly: 3, timeAsString: "19:00",
            stage: TestFixtures.stage(id: 1), artist: TestFixtures.artist(id: 851))
        let later = TestFixtures.event(
            id: 852, dayInJuly: 3, timeAsString: "19:15",
            stage: TestFixtures.stage(id: 1), artist: TestFixtures.artist(id: 852))
        let data = TestFixtures.festivalData(events: [first, later])
        let entries = PlanDayTimeline.shared.entries(
            events: [later, first], transfer: data.coreWalkingTransfers)

        #expect(entries.map(\.event.id) == [851, 852])
        #expect(entries.map(\.hasConflict) == [false, true])
        #expect(entries.last?.previousConflicts.map(\.id) == [851])
    }

    private func makeEvents(startingAt firstID: Int, count: Int) -> [Event] {
        (0..<count).map { offset in
            let id = firstID + offset
            return TestFixtures.event(
                id: id,
                dayInJuly: 3,
                timeAsString: "\(18 + offset):00",
                stage: TestFixtures.stage(id: id),
                artist: TestFixtures.artist(id: id)
            )
        }
    }
}
