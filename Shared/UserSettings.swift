//
// Created by Leon on 03.03.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

import Foundation
import Combine

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T

    var wrappedValue: T {
        get {
            return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

final class UserSettings: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    private var listener: (() -> ())? = nil

    @UserDefault(key: "\(DataStore.year)/ratings", defaultValue: Dictionary())
    var ratings: Dictionary<String, Int>

    @UserDefault(key: "\(DataStore.year)/savedEvents", defaultValue: [])
    var savedEvents: [Int]
    
    @UserDefault(key: "\(DataStore.year)/readNews", defaultValue: [])
    var readNews: [Int]
    
    @UserDefault(key: "\(DataStore.year)/oldNews", defaultValue: [])
    var oldNews: [Int]


    private var notificationSubscription: AnyCancellable?

    init() {
        notificationSubscription = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).sink { a in
            self.objectWillChange.send()
            if let listener = self.listener {
                listener()
            }
        }
    }
    
    func onChange(listener: @escaping () -> ()) {
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
