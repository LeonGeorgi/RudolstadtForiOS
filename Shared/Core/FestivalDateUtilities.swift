import Foundation

enum FestivalDateUtilities {
    static func shortWeekDay(day: Int) -> String {
        weekDay(day: day, dateFormat: "EE")
    }

    static func fullWeekDay(day: Int) -> String {
        weekDay(day: day, dateFormat: "EEEE")
    }

    private static func weekDay(day: Int, dateFormat: String) -> String {
        var dateComponents = DateComponents()
        dateComponents.year = DataStore.year
        dateComponents.month = 7
        dateComponents.day = day
        dateComponents.timeZone = TimeZone(abbreviation: "CEST")

        let userCalendar = Calendar.current
        let date = userCalendar.date(from: dateComponents)!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormat
        return dateFormatter.string(from: date)
    }

    static func getCurrentFestivalDay(eventDays: [Int]) -> Int? {
        let components = Calendar.current.dateComponents(
            [.hour, .day, .month, .year],
            from: Date.now
        )
        guard let hour = components.hour, let day = components.day,
            let month = components.month, let year = components.year
        else {
            return nil
        }
        if year != DataStore.year || month != 7 || !eventDays.contains(day) {
            return nil
        }
        if hour <= 5 {
            return day - 1
        }
        return day
    }
}
