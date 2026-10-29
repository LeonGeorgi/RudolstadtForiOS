import Combine
import Foundation
import RudolstadtCore
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

enum ScheduleDaySelectionStyle: Int {
    case toolbarMenu = 0
    case tabs = 1
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

    private var selectionObservation: StateSubscription?
    private lazy var selection: FestivalSelectionViewModel = {
        let stored = try? JSONDecoder().decode(FestivalIdentity.self, from: selectedFestivalIdentity)
        let legacy =
            selectedFestivalEditionID.isEmpty ? nil : FestivalEdition(id: selectedFestivalEditionID)?.identity
        let year =
            userDefaults.object(forKey: "festival/selectedYear/v1") == nil
            ? nil : FestivalEdition(year: selectedFestivalYear)?.identity
        let model = FestivalSelectionViewModel(
            registered: Set(FestivalEdition.availableEditions.map { $0.identity.core }),
            defaultIdentity: FestivalRegistry.catalog.defaultIdentity.core, preferred: stored?.core,
            legacy: legacy?.core, legacyYear: year?.core, legacyPresent: !selectedFestivalEditionID.isEmpty)
        selectionObservation = model.observe { [weak self] _ in self?.objectWillChange.send() }
        return model
    }()
    var festivalEdition: FestivalEdition {
        get {
            FestivalEdition(
                identity: FestivalIdentity(
                    festivalID: selection.current.identity.festivalID,
                    editionID: selection.current.identity.editionID))
        }
        set {
            selection.select(identity: newValue.identity.core)
            do {
                selectedFestivalIdentity = try JSONEncoder().encode(newValue.identity)
                selectedFestivalEditionID = newValue.legacySelectionID
            } catch { AppLog.app.error("Cannot persist festival selection: \(error.localizedDescription)") }
        }
    }

    let newsHistory = NewsHistoryViewModel()
    var readNews: [Int] {
        get { newsHistory.current.read.map(\.intValue) }
        set { newsHistory.setRead(ids: KotlinCore.ids(newValue)); persistNewsHistory(change: .newsReadState) }
    }
    var oldNews: [Int] {
        get { newsHistory.current.known.map(\.intValue) }
        set { newsHistory.setKnown(ids: KotlinCore.ids(newValue)); persistNewsHistory(change: .oldNewsState) }
    }
    var newsBaselineInitialized: Bool {
        get { newsHistory.current.initialized }
        set { newsHistory.setInitialized(value: newValue); persistNewsHistory(change: nil) }
    }
    func persistNewsHistory(change: UserSettingsChange?) {
        objectWillChange.send()
        userDefaults.set(readNews, forKey: "\(DataStore.year)/readNews")
        userDefaults.set(oldNews, forKey: "\(DataStore.year)/oldNews")
        userDefaults.set(newsBaselineInitialized, forKey: "\(DataStore.year)/newsBaselineInitialized")
        if let change { listeners[change]?.forEach { $0() } }
    }

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

    @UserDefault(key: "view/schedule/day-selection/v1", defaultValue: 0)
    private var scheduleDaySelectionStyleRawValue: Int

    var scheduleDaySelectionStyle: ScheduleDaySelectionStyle {
        get {
            ScheduleDaySelectionStyle(rawValue: scheduleDaySelectionStyleRawValue) ?? .toolbarMenu
        }
        set {
            scheduleDaySelectionStyleRawValue = newValue.rawValue
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
    private let schedulePreferences = SchedulePreferencesViewModel()
    var scheduleFilterType: Int {
        get {
            let scope = FestivalEdition.current.identity.storageKey
            schedulePreferences.restore(
                scope: scope,
                code: Int32(clamping: userDefaults.integer(forKey: "view/schedule/filtertype")))
            return Int(schedulePreferences.storedCode(scope: scope))
        }
        set {
            objectWillChange.send()
            schedulePreferences.restore(
                scope: FestivalEdition.current.identity.storageKey, code: Int32(clamping: newValue))
            userDefaults.set(newValue, forKey: "view/schedule/filtertype")
        }
    }

    @UserDefault(key: "view/artist/ai-summary/v3", defaultValue: true)
    var aiSummaryEnabled: Bool

    @UserDefault(key: "view/artist/likeIcon", defaultValue: "heart.fill")
    var likeIcon: String

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        newsHistory.restore(
            read: KotlinCore.ids(userDefaults.array(forKey: "\(DataStore.year)/readNews") as? [Int] ?? []),
            known: KotlinCore.ids(userDefaults.array(forKey: "\(DataStore.year)/oldNews") as? [Int] ?? []),
            initialized: userDefaults.bool(forKey: "\(DataStore.year)/newsBaselineInitialized"))
    }

    deinit { selectionObservation?.cancel() }

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
        scheduleFilterType = Int(schedulePreferences.codeForName(name: type.rawValue))
    }
    func getScheduleFilterType(_ type: Int) -> ScheduleFilter {
        ScheduleFilter(rawValue: schedulePreferences.name(code: Int32(clamping: type))) ?? .all
    }

    func onChange(of change: UserSettingsChange, perform listener: @escaping () -> Void) {
        listeners[change, default: []].append(listener)
    }

    func idFor(newsItem: NewsItem) -> String {
        return "\(newsItem.id)-\(readNews.contains(newsItem.id))"
    }

    func markNewsAsRead(_ newsItem: NewsItem) { markNewsAsRead([newsItem]) }
    func markNewsAsRead(_ newsItems: [NewsItem]) {
        let old = newsHistory.current.read
        newsHistory.markRead(ids: KotlinCore.ids(newsItems.map(\.id)))
        if old != newsHistory.current.read { persistNewsHistory(change: .newsReadState) }
    }
    func toggleReadState(for newsItem: NewsItem) {
        newsHistory.toggleRead(id: newsItem.newsID)
        persistNewsHistory(change: .newsReadState)
    }

}

typealias UserSettings = UserPreferencesStore


extension UserPreferencesStore {
    func scheduleFilter(for identity: FestivalIdentity) -> ScheduleFilter {
        if identity == FestivalEdition.current.identity { return getScheduleFilterType(scheduleFilterType) }
        let key = "festival/\(identity.storageKey)/schedule-filter/v1"
        schedulePreferences.restore(
            scope: identity.storageKey, code: Int32(clamping: userDefaults.integer(forKey: key)))
        return getScheduleFilterType(
            Int(schedulePreferences.storedCode(scope: identity.storageKey)))
    }

    func setScheduleFilter(_ filter: ScheduleFilter, for identity: FestivalIdentity) {
        if identity == FestivalEdition.current.identity { setScheduleFilterType(type: filter); return }
        let raw = schedulePreferences.select(scope: identity.storageKey, name: filter.rawValue)
        userDefaults.set(Int(raw), forKey: "festival/\(identity.storageKey)/schedule-filter/v1")
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
    private func restoreFestivalNewsHistory(_ identity: FestivalIdentity) -> String {
        let key = "festival/\(identity.storageKey)/read-news/v1"
        if !newsHistory.hasFestivalHistory(scope: key) {
            newsHistory.restoreFestivalHistory(
                scope: key, ids: Set(userDefaults.stringArray(forKey: key) ?? []))
        }
        return key
    }

    func isFestivalNewsRead(_ id: String, identity: FestivalIdentity) -> Bool {
        newsHistory.isArticleRead(
            id: id, scope: restoreFestivalNewsHistory(identity),
            legacy: identity == FestivalEdition.current.identity)
    }

    func markFestivalNewsRead(_ id: String, identity: FestivalIdentity) {
        let key = restoreFestivalNewsHistory(identity)
        switch newsHistory.markArticleRead(
            id: id, scope: key, legacy: identity == FestivalEdition.current.identity)
        {
        case .storeLegacy: persistNewsHistory(change: .newsReadState)
        case .storeFestival:
            userDefaults.set(newsHistory.festivalReadIDs(scope: key), forKey: key)
            objectWillChange.send()
        default: break
        }
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
