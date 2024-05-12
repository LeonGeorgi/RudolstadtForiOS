import Foundation
import SwiftUI

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
    
    static func getCurrentFestivalDay(eventDays: [Int]) -> Int? {
        let components = Calendar.current.dateComponents([.hour, .day, .month, .year], from: Date.now)
        guard let hour = components.hour, let day = components.day, let month = components.month, let year = components.year else {
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


func normalize(string: String) -> String {
    string.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale.current).trimmingCharacters(in: .whitespacesAndNewlines)
}


extension Array {

    func withApplied(searchTerm rawSearchTerm: String, mapper: (Element) -> String) -> [Element] {
        let trimmedSearchTerm = rawSearchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearchTerm.isEmpty {
            return self
        }

        let searchTerm = normalize(string: trimmedSearchTerm)
        return filter { element in
            normalize(string: mapper(element)).contains(searchTerm)
        }
                .enumerated()
                .sorted { element1, element2 in
                    let index1 = element1.offset
                    let index2 = element2.offset

                    let mapped1 = mapper(element1.element)
                    let mapped2 = mapper(element2.element)

                    let string1 = normalize(string: mapped1)
                    let string2 = normalize(string: mapped2)

                    let s1 = string1.starts(with: searchTerm)
                    let s2 = string2.starts(with: searchTerm)

                    return s1 && !s2 || ((s1 || s2) && index1 < index2)
                }
                .map {
                    $0.element
                }
    }

    func withApplied(searchTerm rawSearchTerm: String, matcher: (Element, String) -> Bool) -> [Element] {
        let trimmedSearchTerm = rawSearchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearchTerm.isEmpty {
            return self
        }

        let searchTerm = normalize(string: trimmedSearchTerm)
        return filter { element in
            matcher(element, searchTerm)
        }
    }
}

struct HorizontalSwipeGesture: ViewModifier {
    @State private var swipeStartPosition: CGPoint = .zero
    @State private var isSwiping = false

    var onSwipeLeft: () -> Void
    var onSwipeRight: () -> Void

    func body(content: Content) -> some View {
        content.gesture(DragGesture()
                    .onChanged { gesture in
                        if isSwiping {
                            swipeStartPosition = gesture.location
                            isSwiping.toggle()
                        }
                    }
                    .onEnded { gesture in
                        let xDist = abs(gesture.location.x - swipeStartPosition.x)
                        let yDist = abs(gesture.location.y - swipeStartPosition.y)
                        if swipeStartPosition.x > gesture.location.x && yDist < xDist {
                            onSwipeLeft()
                        }
                        else if swipeStartPosition.x < gesture.location.x && yDist < xDist {
                            onSwipeRight()
                        }
                        isSwiping.toggle()
                    }
        )
    }
}

extension View {
    func horizontalSwipeGesture(onSwipeLeft: @escaping () -> Void, onSwipeRight: @escaping () -> Void) -> some View {
        modifier(HorizontalSwipeGesture(onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight))
    }
}
