#if os(iOS)
import Foundation
import FirebaseFirestore
import RudolstadtCore

@MainActor
final class FirebaseOwnProfileStore: KotlinStateStore<OwnProfileSyncState> {
    let controller: OwnProfileController
    private let transport: FirebaseOwnProfileTransport
    private var projection: StateSubscription?

    init(profile: FestivalProfileStore, defaults: UserDefaults) {
        FirebaseFriendsRuntime.configure()
        let transport = FirebaseOwnProfileTransport(source: profile.cacheSnapshot, defaults: defaults)
        let controller = OwnProfileController(
            edition: "rudolstadt-\(profile.cacheSnapshot.currentProfile.festivalYear)", transport: transport,
            archiveSharing: profile.archiveSharing)
        self.transport = transport
        self.controller = controller
        super.init(current: { controller.current }, observe: controller.observe)
        projection = controller.observe { [weak profile] value in
            guard let profile, value.initialized else { return }
            profile.applyFirebaseProfile(value.profile)
            profile.syncStore.viewModel.account(status: value.uid == nil ? "local" : "available", reason: nil)
            if let problem = value.problem {
                profile.syncStore.viewModel.sync(phase: "error", message: NSLocalizedString(problem.localizationKey, comment: ""), pending: value.pendingCount > 0)
            } else if value.phase == .ready || value.phase == .local {
                profile.syncStore.viewModel.confirmSuccess()
            } else {
                profile.syncStore.viewModel.sync(phase: "syncing", message: nil, pending: value.pendingCount > 0)
            }
            if let date = value.lastSyncedAt { profile.syncStore.viewModel.refreshed(at: date) }
        }
        if controller.current.initialized { profile.applyFirebaseProfile(controller.current.profile) }
    }

    nonisolated static func journalKey(year: Int) -> String { "firebase-own-profile-\(year)-v1" }

    deinit {
        projection?.cancel()
        Task { @MainActor [controller] in controller.close() }
    }
}

/** UserDefaults and SDK boundaries only. The source is captured before any Firebase projection. */
private final class FirebaseOwnProfileTransport: NSObject, OwnProfileTransport {
    private let source: FestivalProfileCache
    private let defaults: UserDefaults
    private let backend = FirebaseFriendsTransport(enabled: true)
    private let key: String

    init(source: FestivalProfileCache, defaults: UserDefaults) {
        self.source = source
        self.defaults = defaults
        key = FirebaseOwnProfileStore.journalKey(year: source.currentProfile.festivalYear)
    }
    func observeAccount(changed: @escaping (String?) -> Void) -> any FriendsSubscription { backend.observeAccount(changed: changed) }
    func checkAccountDeleted(owner: String, completed: @escaping (KotlinBoolean) -> Void) {
        let payload = (try? JSONSerialization.data(withJSONObject: ["owner": owner])).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        backend.call(name: "accountDeletionStatus", payload: payload) { value, error in
            let deleted = value.flatMap { $0.data(using: .utf8) }.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["deleted"] as? Bool ?? false
            _ = completed(KotlinBoolean(bool: error == nil && deleted))
        }
    }
    func signOutDeletedAccount(owner: String, completed: @escaping (FriendsTransportError?) -> Void) { backend.signOutDeletedAccount(owner: owner, completed: completed) }

    func loadLocal(completed: @escaping (String?, FriendsTransportError?) -> Void) {
        do {
            let backupKey = "\(key)-legacy-backup"
            if defaults.data(forKey: backupKey) == nil {
                let backup = try JSONEncoder().encode(source)
                defaults.set(backup, forKey: backupKey)
                guard defaults.data(forKey: backupKey) == backup else { completed(nil, .failed); return }
            }
            let stored = defaults.data(forKey: key)
            let journal = stored.flatMap { String(data: $0, encoding: .utf8) }
            guard stored == nil || journal != nil else { completed(nil, .failed); return }
            completed(try OwnProfileData.shared.encodeLocal(journal: journal,
                profile: source.currentProfile.domainProfile, changes: source.currentProfile.domainChanges), nil)
        } catch { completed(nil, .failed) }
    }
    func saveLocal(journal: String, profile: String, completed: @escaping (FriendsTransportError?) -> Void) {
        // The single journal contains every account, version, queue and full profile projection.
        let data = Data(journal.utf8)
        defaults.set(data, forKey: key)
        completed(defaults.data(forKey: key) == data ? nil : .failed)
    }
    func observeRecords(edition: String, owner: String, changed: @escaping (String?, KotlinBoolean, FriendsTransportError?) -> Void) -> any FriendsSubscription {
        let listener = Firestore.firestore().collection("users").document(owner).collection("profileEditions")
            .document(edition).collection("records").addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
                guard let snapshot, error == nil else { changed(nil, KotlinBoolean(bool: false), error?.friendsTransportError ?? .failed); return }
                do {
                    let data = try JSONSerialization.data(withJSONObject: snapshot.documents.map { $0.data() })
                    changed(String(decoding: data, as: UTF8.self), KotlinBoolean(bool: !snapshot.metadata.isFromCache), nil)
                } catch { changed(nil, KotlinBoolean(bool: false), .failed) }
            }
        return FirebaseFriendsSubscription { listener.remove() }
    }
    func syncRecords(payload: String, completed: @escaping (String?, FriendsTransportError?) -> Void) {
        backend.call(name: "syncOwnProfile", payload: payload, completed: completed)
    }
}

extension OwnProfileProblem {
    var localizationKey: String {
        switch self {
        case .localStorage: "profile.sync.error.local"
        default: "profile.sync.error.connection"
        }
    }
}
extension OwnProfilePhase {
    var localizationKey: String {
        switch self {
        case .loading: "profile.sync.loading"
        case .local: "profile.sync.local"
        case .connecting: "profile.sync.connecting"
        case .migrating: "profile.sync.migrating"
        case .ready: "profile.sync.ready"
        case .error: "profile.sync.error"
        default: "profile.sync.syncing"
        }
    }
}
#endif
