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

    let userDefaults: UserDefaults
    private var listeners: [UserSettingsChange: [() -> Void]] = [:]

    @UserDefault(key: "festival/selectedYear/v1", defaultValue: FestivalConfiguration.year)
    private var selectedFestivalYear: Int

    @UserDefault(key: "festival/selectedEdition/v1", defaultValue: "")
    private var selectedFestivalEditionID: String

    @UserDefault(key: "festival/selectedIdentity/v2", defaultValue: Data())
    private var selectedFestivalIdentity: Data

    var festivalEdition: FestivalEdition {
        get {
            if let identity = try? JSONDecoder().decode(FestivalIdentity.self, from: selectedFestivalIdentity),
               let adapter = FestivalRegistry.catalog.adapter(for: identity) {
                return FestivalEdition(metadata: adapter.metadata)
            }
            if !selectedFestivalEditionID.isEmpty {
                return FestivalEdition(id: selectedFestivalEditionID) ?? FestivalEdition(identity: FestivalRegistry.catalog.defaultIdentity)
            }
            if userDefaults.object(forKey: "festival/selectedYear/v1") != nil,
               let legacy = FestivalEdition(year: selectedFestivalYear) { return legacy }
            return FestivalEdition(identity: FestivalRegistry.catalog.defaultIdentity)
        }
        set {
            do {
                selectedFestivalIdentity = try JSONEncoder().encode(newValue.identity)
                selectedFestivalEditionID = newValue.legacySelectionID
            } catch { AppLog.app.error("Cannot persist festival selection: \(error.localizedDescription)") }
        }
    }

    @UserDefault(key: "\(DataStore.year)/readNews", defaultValue: [])
    var readNews: [Int]

    @UserDefault(key: "\(DataStore.year)/oldNews", defaultValue: [])
    var oldNews: [Int]

    @UserDefault(key: "\(DataStore.year)/newsBaselineInitialized", defaultValue: false)
    var newsBaselineInitialized: Bool

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

    var artistPresentationMode: ArtistPresentationMode {
        get {
            ArtistPresentationMode(rawValue: artistViewType) ?? .grid
        }
        set {
            artistViewType = newValue.rawValue
        }
    }

    // 2 - Comfortable grid
    // 3 - Compact grid
    @UserDefault(key: "view/artist/grid-columns/v1", defaultValue: 2)
    var artistGridColumnCount: Int

    var artistGridDensity: ArtistGridDensity {
        get {
            ArtistGridDensity(rawValue: artistGridColumnCount) ?? .comfortable
        }
        set {
            artistGridColumnCount = newValue.rawValue
        }
    }

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


extension UserPreferencesStore {
    func scheduleFilter(for identity: FestivalIdentity) -> ScheduleFilter {
        if identity == FestivalEdition.current.identity { return getScheduleFilterType(scheduleFilterType) }
        let key = "festival/\(identity.storageKey)/schedule-filter/v1"
        return getScheduleFilterType(userDefaults.integer(forKey: key))
    }

    func setScheduleFilter(_ filter: ScheduleFilter, for identity: FestivalIdentity) {
        if identity == FestivalEdition.current.identity { setScheduleFilterType(type: filter); return }
        let raw: Int
        switch filter { case .all: raw = 0; case .interesting: raw = 1; case .optimal: raw = 2; case .saved: raw = 3 }
        userDefaults.set(raw, forKey: "festival/\(identity.storageKey)/schedule-filter/v1")
        objectWillChange.send()
    }
}

extension UserPreferencesStore {
    func selectedMap(for identity: FestivalIdentity) -> String? {
        userDefaults.string(forKey: "festival/\(identity.storageKey)/selected-map/v1")
    }
    func setSelectedMap(_ id: String, for identity: FestivalIdentity) {
        userDefaults.set(id, forKey: "festival/\(identity.storageKey)/selected-map/v1")
    }
}


extension UserPreferencesStore {
    func isFestivalNewsRead(_ id: String, identity: FestivalIdentity) -> Bool {
        if identity == FestivalEdition.current.identity, let legacyID = Int(id) { return readNews.contains(legacyID) }
        return userDefaults.stringArray(forKey: "festival/\(identity.storageKey)/read-news/v1")?.contains(id) == true
    }

    func markFestivalNewsRead(_ id: String, identity: FestivalIdentity) {
        if identity == FestivalEdition.current.identity, let legacyID = Int(id) {
            if !readNews.contains(legacyID) { readNews.append(legacyID) }
            return
        }
        let key = "festival/\(identity.storageKey)/read-news/v1"
        var ids = Set(userDefaults.stringArray(forKey: key) ?? [])
        ids.insert(id)
        userDefaults.set(ids.sorted(), forKey: key)
        objectWillChange.send()
    }
}


extension UserPreferencesStore {
    func mapVisibility(for identity: FestivalIdentity) -> (categories: Set<String>, legend: Bool)? {
        let key = "festival/\(identity.storageKey)/map-visibility/v1"
        guard let value = userDefaults.dictionary(forKey: key), let categories = value["categories"] as? [String] else { return nil }
        return (Set(categories), value["legend"] as? Bool ?? true)
    }
    func setMapVisibility(categories: Set<String>, legend: Bool, for identity: FestivalIdentity) {
        userDefaults.set(["categories": categories.sorted(), "legend": legend],
            forKey: "festival/\(identity.storageKey)/map-visibility/v1")
    }
}
