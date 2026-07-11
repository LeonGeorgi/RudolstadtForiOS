import Testing
@testable import Rudolstadt

struct SchedulePresenterTests {
    @Test
    func optimalFilterShowsSavedAndRecommendedEvents() {
        let events = makeEvents(startingAt: 801, count: 3)
        let presenter = SchedulePresenter(
            festivalData: TestFixtures.festivalData(events: events),
            recommendationState: .success([802]),
            scheduleFilterType: .optimal,
            savedEventIds: [801],
            positiveRatedArtistIds: [],
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
            recommendationState: .loading,
            scheduleFilterType: .interesting,
            savedEventIds: [811],
            positiveRatedArtistIds: [812],
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
            recommendationState: .loading,
            scheduleFilterType: .saved,
            savedEventIds: [822],
            positiveRatedArtistIds: [],
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
            recommendationState: .loading,
            scheduleFilterType: .all,
            savedEventIds: [],
            positiveRatedArtistIds: [],
            calendar: TestFixtures.festivalCalendar
        )

        guard case .success(let shownEvents) = presenter.shownEvents else {
            Issue.record("Expected shown events")
            return
        }
        #expect(shownEvents.map(\.id) == [831, 832])
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
