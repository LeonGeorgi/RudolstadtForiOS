import Foundation
import Testing
@testable import Rudolstadt

struct FestivalDateUtilitiesTests {
    private let calendar = TestFixtures.festivalCalendar

    @Test
    func fullWeekDayUsesExplicitLocale() {
        let germanWeekDay = FestivalDateUtilities.fullWeekDay(
            day: 2,
            calendar: calendar,
            locale: Locale(identifier: "de_DE")
        )
        let englishWeekDay = FestivalDateUtilities.fullWeekDay(
            day: 2,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        #expect(germanWeekDay == "Donnerstag")
        #expect(englishWeekDay == "Thursday")
    }

    @Test
    func weekDayIsIndependentOfRunnerTimeZone() {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = .gmt

        let firstFestivalWeekDay = FestivalDateUtilities.fullWeekDay(
            day: 2,
            calendar: utcCalendar,
            locale: Locale(identifier: "de_DE")
        )
        let lastFestivalWeekDay = FestivalDateUtilities.fullWeekDay(
            day: 5,
            calendar: utcCalendar,
            locale: Locale(identifier: "de_DE")
        )

        #expect(firstFestivalWeekDay == "Donnerstag")
        #expect(lastFestivalWeekDay == "Sonntag")
    }

    @Test
    func earlyMorningBelongsToPreviousFestivalDay() {
        let now = TestFixtures.date(
            dayInJuly: 4,
            hour: 4,
            minute: 30,
            calendar: calendar
        )

        let festivalDay = FestivalDateUtilities.getCurrentFestivalDay(
            eventDays: [2, 3, 4, 5],
            now: now,
            calendar: calendar
        )

        #expect(festivalDay == 3)
    }

    @Test
    func daytimeBelongsToCalendarFestivalDay() {
        let now = TestFixtures.date(
            dayInJuly: 4,
            hour: 6,
            minute: 0,
            calendar: calendar
        )

        let festivalDay = FestivalDateUtilities.getCurrentFestivalDay(
            eventDays: [2, 3, 4, 5],
            now: now,
            calendar: calendar
        )

        #expect(festivalDay == 4)
    }

    @Test
    func dateOutsideFestivalReturnsNil() {
        let now = TestFixtures.date(
            dayInJuly: 8,
            hour: 12,
            minute: 0,
            calendar: calendar
        )

        let festivalDay = FestivalDateUtilities.getCurrentFestivalDay(
            eventDays: [2, 3, 4, 5],
            now: now,
            calendar: calendar
        )

        #expect(festivalDay == nil)
    }

    @Test
    func eventTimeCalculationsUseExplicitCalendar() {
        let event = TestFixtures.event(
            id: 1,
            dayInJuly: 4,
            timeAsString: "03:30",
            stage: TestFixtures.stage(id: 1),
            artist: TestFixtures.artist(id: 1)
        )

        #expect(event.festivalDay(calendar: calendar) == 3)
        #expect(event.startTimeInMinutes(calendar: calendar) == 27 * 60 + 30)
    }
}

struct LocalizationDependencyTests {
    @Test
    func artistDescriptionUsesExplicitLocale() {
        let artist = TestFixtures.artist(
            id: 2,
            descriptionGerman: "Deutsche Beschreibung",
            descriptionEnglish: "English description"
        )

        #expect(
            artist.formattedDescription(locale: Locale(identifier: "de_DE"))
                == "Deutsche Beschreibung"
        )
        #expect(
            artist.formattedDescription(locale: Locale(identifier: "en_US"))
                == "English description"
        )
    }
}
