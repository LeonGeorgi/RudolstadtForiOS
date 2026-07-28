import Foundation

enum FestivalDateUtilities {
    private static let festivalTimeZone: TimeZone = {
        guard let timeZone = TimeZone(identifier: "Europe/Berlin") else {
            preconditionFailure("Europe/Berlin time zone is unavailable")
        }
        return timeZone
    }()

    static func calendarInFestivalTimeZone(
        basedOn calendar: Calendar = .current
    ) -> Calendar {
        var festivalCalendar = calendar
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
        let festivalCalendar = calendarInFestivalTimeZone(basedOn: calendar)

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
