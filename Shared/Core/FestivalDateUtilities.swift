import Foundation

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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone ?? festivalTimeZone
        formatter.dateFormat = format
        formatter.isLenient = false
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
            return nil
        }
        return date
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
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        weekDay(
            day: day,
            dateFormat: "EE",
            calendar: calendar,
            locale: locale
        )
    }

    static func fullWeekDay(
        day: Int,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        weekDay(
            day: day,
            dateFormat: "EEEE",
            calendar: calendar,
            locale: locale
        )
    }

    private static func weekDay(
        day: Int,
        dateFormat: String,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        guard day > 0 else { return NSLocalizedString("event.date.unknown", comment: "") }
        let festivalCalendar = Self.festivalCalendar

        let dateComponents = DateComponents(
            calendar: festivalCalendar,
            timeZone: festivalTimeZone,
            year: DataStore.year,
            month: 7,
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
        calendar: Calendar = .current
    ) -> Int? {
        let festivalCalendar = calendarInFestivalTimeZone(basedOn: calendar)
        let components = festivalCalendar.dateComponents(
            [.hour, .day, .month, .year],
            from: now
        )
        guard let hour = components.hour, let day = components.day,
            let month = components.month, let year = components.year
        else {
            return nil
        }
        guard year == DataStore.year, month == 7 else {
            return nil
        }
        let festivalDay = hour < 5 ? day - 1 : day
        return eventDays.contains(festivalDay) ? festivalDay : nil
    }
}
