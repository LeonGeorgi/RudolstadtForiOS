import Combine
import Foundation
import SwiftUI

enum UserSettingsChange: Hashable {
    case recommendationInputs
    case newsReadState
    case oldNewsState
}

enum ScheduleDisplayMode: Int {
    case timeline = 0
    case list = 1
}

enum NotificationPromptState: Int {
    case notPresented
    case deferred
    case systemPromptRequested
}

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T

    @available(*, unavailable, message: "Use this property wrapper only on UserPreferencesStore.")
    var wrappedValue: T {
        get {
            fatalError("wrappedValue is unavailable")
        }
        set {
            fatalError("wrappedValue is unavailable")
        }
    }

    @MainActor
    static subscript<EnclosingSelf: UserPreferencesStore>(
        _enclosingInstance instance: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, T>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, UserDefault<T>>
    ) -> T {
        get {
            let wrapper = instance[keyPath: storageKeyPath]
            return instance.userDefaults.object(forKey: wrapper.key) as? T
                ?? wrapper.defaultValue
        }
        set {
            let wrapper = instance[keyPath: storageKeyPath]
            instance.objectWillChange.send()
            instance.userDefaults.set(newValue, forKey: wrapper.key)
            instance.notifySettingsDidChange(forKey: wrapper.key)
        }
    }
}

@MainActor
final class UserPreferencesStore: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()

    fileprivate let userDefaults: UserDefaults
    private var listeners: [UserSettingsChange: [() -> Void]] = [:]

    @UserDefault(key: "\(DataStore.year)/readNews", defaultValue: [])
    var readNews: [Int]

    @UserDefault(key: "\(DataStore.year)/oldNews", defaultValue: [])
    var oldNews: [Int]

    @UserDefault(key: "notifications/newsPrompt/v1", defaultValue: 0)
    private var notificationPromptStateRawValue: Int

    var notificationPromptState: NotificationPromptState {
        get {
            NotificationPromptState(rawValue: notificationPromptStateRawValue)
                ?? .notPresented
        }
        set {
            notificationPromptStateRawValue = newValue.rawValue
        }
    }

    // 0 - Map
    // 1 - List
    @UserDefault(key: "view/locations/viewtype", defaultValue: 0)
    var mapType: Int

    // 0 - Timeline
    // 1 - List
    @UserDefault(key: "view/schedule/viewtype", defaultValue: 0)
    var scheduleViewType: Int

    var scheduleDisplayMode: ScheduleDisplayMode {
        get {
            ScheduleDisplayMode(rawValue: scheduleViewType) ?? .timeline
        }
        set {
            scheduleViewType = newValue.rawValue
        }
    }

    // 0 - List
    // 1 - Grid
    @UserDefault(key: "view/artist/viewtype/v2", defaultValue: 1)
    var artistViewType: Int

    // 0 - All
    // 1 - Favorites
    // 2 - Optimal
    // 3 - Saved
    @UserDefault(key: "view/schedule/filtertype", defaultValue: 0)
    var scheduleFilterType: Int
    
    @UserDefault(key: "view/artist/ai-summary/v3", defaultValue: true)
    var aiSummaryEnabled: Bool
    
    @UserDefault(key: "view/artist/likeIcon", defaultValue: "heart.fill")
    var likeIcon: String

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    fileprivate func notifySettingsDidChange(forKey key: String) {
        guard let change = changeType(forKey: key) else {
            return
        }
        listeners[change]?.forEach { listener in
            listener()
        }
    }

    private func changeType(forKey key: String) -> UserSettingsChange? {
        switch key {
        case "\(DataStore.year)/readNews":
            return .newsReadState
        case "\(DataStore.year)/oldNews":
            return .oldNewsState
        default:
            return nil
        }
    }

    func toggleMapType() {
        if mapType == 0 {
            mapType = 1
        } else {
            mapType = 0
        }
    }

    func toggleScheduleDisplayMode() {
        switch scheduleDisplayMode {
        case .timeline:
            scheduleDisplayMode = .list
        case .list:
            scheduleDisplayMode = .timeline
        }
    }

    func toggleArtistViewType() {
        if artistViewType == 0 {
            artistViewType = 1
        } else {
            artistViewType = 0
        }
    }

    func setScheduleFilterType(type: ScheduleFilter) {
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

    func getScheduleFilterType(_ type: Int) -> ScheduleFilter {
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

    func onChange(of change: UserSettingsChange, perform listener: @escaping () -> Void) {
        listeners[change, default: []].append(listener)
    }

    func idFor(newsItem: NewsItem) -> String {
        return "\(newsItem.id)-\(readNews.contains(newsItem.id))"
    }

    func markNewsAsRead(_ newsItem: NewsItem) {
        if !readNews.contains(newsItem.id) {
            readNews.append(newsItem.id)
        }
    }

    func markNewsAsRead(_ newsItems: [NewsItem]) {
        var updatedReadNews = readNews
        var readNewsIDs = Set(updatedReadNews)

        for newsItem in newsItems where readNewsIDs.insert(newsItem.id).inserted {
            updatedReadNews.append(newsItem.id)
        }

        if updatedReadNews != readNews {
            readNews = updatedReadNews
        }
    }

    func toggleReadState(for newsItem: NewsItem) {
        if readNews.contains(newsItem.id) {
            readNews.removeAll { id in
                id == newsItem.id
            }
        } else {
            readNews.append(newsItem.id)
        }
    }
}

typealias UserSettings = UserPreferencesStore
