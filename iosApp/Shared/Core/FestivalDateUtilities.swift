import Foundation
import RudolstadtCore

enum FestivalDateUtilities {
    private static let festivalTimeZone: TimeZone = {
        guard let timeZone = TimeZone(identifier: "Europe/Berlin") else {
            preconditionFailure("Europe/Berlin time zone is unavailable")
        }
        return timeZone
    }()

    static var festivalCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = festivalTimeZone
        return calendar
    }

    static func parse(_ value: String, format: String, timeZone: TimeZone? = nil) -> Date? {
        KotlinCore.bridge.parseDate(value: value, pattern: format, zone: (timeZone ?? festivalTimeZone).identifier)
            .map { Date(timeIntervalSince1970: $0.doubleValue) }
    }

    static func festivalDate(_ value: String, format: String) -> Date? {
        guard let date = parse(value, format: format),
            festivalCalendar.component(.year, from: date) == FestivalConfiguration.year
        else {
            return nil
        }
        return date
    }

    static func format(_ date: Date, pattern: String, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = festivalCalendar
        formatter.timeZone = festivalTimeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    static func calendarInFestivalTimeZone(
        basedOn calendar: Calendar = .current
    ) -> Calendar {
        var festivalCalendar = Self.festivalCalendar
        festivalCalendar.locale = calendar.locale
        festivalCalendar.timeZone = festivalTimeZone
        return festivalCalendar
    }

    static func shortWeekDay(
        day: Int,
        year: Int = FestivalConfiguration.year,
        month: Int = 7,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        weekDay(
            day: day,
            year: year,
            month: month,
            dateFormat: "EE",
            calendar: calendar,
            locale: locale
        )
    }

    static func fullWeekDay(
        day: Int,
        year: Int = FestivalConfiguration.year,
        month: Int = 7,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        weekDay(
            day: day,
            year: year,
            month: month,
            dateFormat: "EEEE",
            calendar: calendar,
            locale: locale
        )
    }

    private static func weekDay(
        day: Int,
        year: Int,
        month: Int,
        dateFormat: String,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        guard day > 0 else { return NSLocalizedString("event.date.unknown", comment: "") }
        let festivalCalendar = Self.festivalCalendar

        let dateComponents = DateComponents(
            calendar: festivalCalendar,
            timeZone: festivalTimeZone,
            year: year,
            month: month,
            day: day
        )

        guard let date = festivalCalendar.date(from: dateComponents) else {
            return ""
        }
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = festivalCalendar
        dateFormatter.locale = locale
        dateFormatter.timeZone = festivalTimeZone
        dateFormatter.dateFormat = dateFormat
        return dateFormatter.string(from: date)
    }

    static func getCurrentFestivalDay(
        eventDays: [Int],
        now: Date = .now,
        calendar: Calendar = .current,
        festivalYear: Int = FestivalConfiguration.year,
        festivalMonth: Int = 7
    ) -> Int? {
        KotlinCore.bridge.currentDay(days: eventDays.map { RudolstadtCore.KotlinInt(value: Int32($0)) }, now: now.timeIntervalSince1970,
            year: Int32(festivalYear), month: Int32(festivalMonth)).map { Int($0.intValue) }
    }
}
