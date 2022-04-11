import Foundation

class Util {
    static func shortWeekDay(day: Int) -> String {
        var dateComponents = DateComponents()
        dateComponents.year = DataStore.year
        dateComponents.month = 7
        dateComponents.day = day
        dateComponents.timeZone = TimeZone(abbreviation: "CEST")

        let userCalendar = Calendar.current // user calendar
        let date = userCalendar.date(from: dateComponents)!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EE"
        return dateFormatter.string(from: date)
    }
}


func normalize(string: String) -> String {
    string.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale.current)
}

extension Array {
    func withApplied(searchTerm rawSearchTerm: String, mapper: (Element) -> String) -> [Element] {

        let searchTerm = normalize(string: rawSearchTerm)
        return filter { element in
            normalize(string: mapper(element)).contains(searchTerm)
        }
                .sorted { element1, element2 in
                    let mapped1 = mapper(element1)
                    let mapped2 = mapper(element2)

                    let string1 = normalize(string: mapped1)
                    let string2 = normalize(string: mapped2)

                    let s1 = string1.starts(with: searchTerm)
                    let s2 = string2.starts(with: searchTerm)

                    return s1 && !s2 || ((s1 || s2) && string1 < string2)
                }
    }
}
