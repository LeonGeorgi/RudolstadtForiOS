import Foundation
import Testing
@testable import Rudolstadt

struct FestivalDateUtilitiesTests {
    private let calendar = TestFixtures.festivalCalendar

    @Test
    func eventFormattingKeepsMidnightAndLocalizedWeekdayPunctuation() {
        let event = TestFixtures.event(
            id: 1, dayInJuly: 2, timeAsString: "00:05",
            stage: TestFixtures.stage(id: 1), artist: TestFixtures.artist(id: 1))
        #expect(event.timeAsString == "00:05")
        #expect(event.shortWeekDay(calendar: calendar, locale: Locale(identifier: "de_DE")) == "Do.")
        #expect(event.weekDay(calendar: calendar, locale: Locale(identifier: "de_DE")) == "Donnerstag")
        #expect(event.shortWeekDay(calendar: calendar, locale: Locale(identifier: "en_US")) == "Thu")
    }

    @Test
    func archiveWeekdaysAndCurrentDayUseTheExplicitFestivalYear() throws {
        #expect(FestivalDateUtilities.shortWeekDay(
            day: 4, year: 2024, locale: Locale(identifier: "en_US")
        ) == "Thu")
        #expect(FestivalDateUtilities.fullWeekDay(
            day: 7, year: 2024, locale: Locale(identifier: "de_DE")
        ) == "Sonntag")
        let archiveMorning = try #require(FestivalDateUtilities.parse(
            "2024-07-05 04:30", format: "yyyy-MM-dd HH:mm"
        ))
        #expect(FestivalDateUtilities.getCurrentFestivalDay(
            eventDays: [4, 5, 6, 7], now: archiveMorning, festivalYear: 2024
        ) == 4)
        #expect(FestivalDateUtilities.getCurrentFestivalDay(
            eventDays: [4, 5, 6, 7], now: archiveMorning, festivalYear: 2026
        ) == nil)
    }

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
    func fiveOClockBelongsToCalendarFestivalDay() {
        let now = TestFixtures.date(
            dayInJuly: 4,
            hour: 5,
            minute: 0,
            calendar: calendar
        )

        let festivalDay = FestivalDateUtilities.getCurrentFestivalDay(
            eventDays: [3, 4],
            now: now,
            calendar: calendar
        )

        #expect(festivalDay == 4)
    }

    @Test
    func earlyMorningOnlyRequiresPreviousFestivalDayInProgram() {
        let now = TestFixtures.date(
            dayInJuly: 4,
            hour: 4,
            minute: 30,
            calendar: calendar
        )

        let festivalDay = FestivalDateUtilities.getCurrentFestivalDay(
            eventDays: [3],
            now: now,
            calendar: calendar
        )

        #expect(festivalDay == 3)
    }

    @Test
    func currentFestivalDayUsesBerlinTimeForForeignDeviceCalendar() {
        var tokyoCalendar = Calendar(identifier: .gregorian)
        tokyoCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        let berlinLateEvening = TestFixtures.date(
            dayInJuly: 3,
            hour: 22,
            minute: 30,
            calendar: calendar
        )

        let festivalDay = FestivalDateUtilities.getCurrentFestivalDay(
            eventDays: [3, 4],
            now: berlinLateEvening,
            calendar: tokyoCalendar
        )

        #expect(festivalDay == 3)
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
