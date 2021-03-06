//
//  Util.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.03.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

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
