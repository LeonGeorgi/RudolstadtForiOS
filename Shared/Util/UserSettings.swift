//
// Created by Leon on 03.03.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

import Combine
import Foundation
import SwiftUI

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T

    var wrappedValue: T {
        get {
            UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

final class UserSettings: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    private var listener: (() -> Void)? = nil

    @UserDefault(key: "\(DataStore.year)/ratings", defaultValue: Dictionary())
    var ratings: [String: Int]

    @UserDefault(key: "\(DataStore.year)/savedEvents", defaultValue: [])
    var savedEvents: [Int]

    @UserDefault(key: "\(DataStore.year)/readNews", defaultValue: [])
    var readNews: [Int]

    @UserDefault(key: "\(DataStore.year)/oldNews", defaultValue: [])
    var oldNews: [Int]

    @UserDefault(
        key: "\(DataStore.year)/artistNotes",
        defaultValue: Dictionary()
    )
    var artistNotes: [String: String]

    // 0 - Map
    // 1 - List
    @UserDefault(key: "view/locations/viewtype", defaultValue: 0)
    var mapType: Int

    // 0 - Table
    // 1 - List
    @UserDefault(key: "view/schedule/viewtype", defaultValue: 0)
    var scheduleViewType: Int

    // 0 - All
    // 1 - Favorites
    // 2 - Optimal
    // 3 - Saved
    @UserDefault(key: "view/schedule/filtertype", defaultValue: 0)
    var scheduleFilterType: Int
    
    @UserDefault(key: "view/artist/ai-summary/v3", defaultValue: true)
    var aiSummaryEnabled: Bool

    private var notificationSubscription: AnyCancellable?

    init() {
        notificationSubscription = NotificationCenter.default.publisher(
            for: UserDefaults.didChangeNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { a in
            self.objectWillChange.send()
            if let listener = self.listener {
                listener()
            }
        }
    }

    func toggleMapType() {
        if mapType == 0 {
            mapType = 1
        } else {
            mapType = 0
        }
    }

    func toggleScheduleViewType() {
        if scheduleViewType == 0 {
            scheduleViewType = 1
        } else {
            scheduleViewType = 0
        }
    }

    func setScheduleFilterType(type: ScheduleType) {
        switch type {
        case .all:
            scheduleFilterType = 0
        case .interesting:
            scheduleFilterType = 1
        case .optimal:
            scheduleFilterType = 2
        case .saved:
            scheduleFilterType = 3
        }
    }

    func getScheduleFilterType(_ type: Int) -> ScheduleType {
        switch type {
        case 0:
            return .all
        case 1:
            return .interesting
        case 2:
            return .optimal
        case 3:
            return .saved
        default:
            return .all
        }
    }

    func onChange(listener: @escaping () -> Void) {
        self.listener = listener
    }

    func toggleSavedEvent(_ event: Event) {
        if !savedEvents.contains(event.id) {
            savedEvents.append(event.id)
        } else {
            savedEvents.remove(at: savedEvents.firstIndex(of: event.id)!)
        }
    }

    func idFor(event: Event) -> String {
        return "\(event.id)-\(savedEvents.contains(event.id))"
    }

    func idFor(newsItem: NewsItem) -> String {
        return "\(newsItem.id)-\(readNews.contains(newsItem.id))"

    }
}
