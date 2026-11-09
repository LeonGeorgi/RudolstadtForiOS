#if os(iOS)
import Combine
import Foundation
    import RudolstadtCore
import WatchConnectivity

enum WatchSnapshotTransportRuntime {
    static var isEnabled: Bool {
        isEnabled(
            environment: ProcessInfo.processInfo.environment,
            screenshotModeEnabled: ScreenshotRuntime.isEnabled
        )
    }

    static func isEnabled(
        environment: [String: String],
        screenshotModeEnabled: Bool
    ) -> Bool {
        !screenshotModeEnabled
            && environment["XCTestConfigurationFilePath"] == nil
            && environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
    }
}

@MainActor
final class WatchSnapshotCoordinator {
    private let dataStore: DataStore
    private let profileStore: FestivalProfileStore
    private let sender: WatchSnapshotSender
    private let revisionGenerator: WatchSnapshotRevisionGenerator
    private let builder = WatchSnapshotBuilder()
    private let codec = WatchSnapshotCodec()
    private var pendingPublishTask: Task<Void, Never>?
    private var recommendationObservation: AnyCancellable?

    init(
        dataStore: DataStore,
        profileStore: FestivalProfileStore,
        userDefaults: UserDefaults = .standard
    ) {
        self.dataStore = dataStore
        self.profileStore = profileStore
        self.sender = WatchSnapshotSender()
        self.revisionGenerator = WatchSnapshotRevisionGenerator(
            userDefaults: userDefaults,
            festivalYear: DataStore.year
        )

        dataStore.onWatchSnapshotInputsChange = { [weak self] in
            self?.schedulePublish()
        }
        profileStore.onChange(of: .watchSnapshotInputs) { [weak self] in
            self?.schedulePublish()
        }
            recommendationObservation = dataStore.recommendationStore.objectWillChange
            .sink { [weak self] _ in
                self?.schedulePublish()
            }
        sender.start()
        schedulePublish()
    }

    deinit {
        pendingPublishTask?.cancel()
    }

    func schedulePublish() {
        pendingPublishTask?.cancel()
        pendingPublishTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(180))
            } catch is CancellationError {
                return
            } catch {
                AppLog.watchSync.error(
                    "Watch snapshot debounce failed: \(error.localizedDescription, privacy: .public)"
                )
                return
            }
            guard !Task.isCancelled else {
                return
            }
            self?.publishCurrentSnapshot()
        }
    }

    private func publishCurrentSnapshot() {
        guard case .success(let festivalData) = dataStore.festivalData else {
            AppLog.watchSync.debug(
                "Skipped Watch snapshot because festival data is unavailable"
            )
            return
        }
        guard let provenance = dataStore.festivalDataProvenance else {
            AppLog.watchSync.error(
                "Skipped Watch snapshot because festival data provenance is unknown"
            )
            return
        }
        guard dataStore.edition.usesLiveServices, provenance.source != .screenshot,
              provenance.source != .bundledArchive, provenance.source != .bundledExperiment else {
            AppLog.watchSync.debug("Skipped screenshot data for Watch transport")
            return
        }

        let generatedAt = Date.now
        let recommendations = makeRecommendationSnapshot()
        let friends = makeFriendSnapshot()
        let buildResult = builder.build(WatchSnapshotBuildInput(
            festivalYear: DataStore.year,
            revision: revisionGenerator.next(),
            generatedAt: generatedAt,
            environment: .production,
            freshness: WatchSnapshotFreshness(
                festivalDataSource: watchFestivalDataSource(from: provenance.source),
                festivalDataUpdatedAt: provenance.dataUpdatedAt,
                refreshCheckedAt: provenance.refreshCheckedAt,
                profileCloudRefreshedAt: profileStore.syncStore.lastSuccessfulRefreshDate,
                        recommendationsGeneratedAt: dataStore.recommendationStore.state.generatedAt?.date
            ),
            events: festivalData.events,
            savedEventIDs: Set(profileStore.savedEvents),
            ratingsByArtistID: profileStore.ratings,
            estimatedDurationsByEventID:
                festivalData.eventDurations,
            recommendations: recommendations,
            friends: friends,
            friendProfiles: profileStore.acceptedFriendProfiles,
            transitionEvaluator: festivalData.transitionEvaluator(),
            omittedRecordCount: festivalData.omittedRecordCount
        ))

        do {
            let data = try codec.encode(buildResult.envelope)
            sender.enqueue(
                data: data,
                revision: buildResult.envelope.revision
            )
            AppLog.watchSync.info(
                "Prepared Watch snapshot revision \(buildResult.envelope.revision) with \(buildResult.envelope.payload.events.count) events, \(data.count) bytes, and \(buildResult.diagnostics.count) non-fatal diagnostics"
            )
        } catch {
            AppLog.watchSync.error(
                "Could not encode Watch snapshot: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func makeRecommendationSnapshot() -> WatchRecommendationSnapshot {
            let state = dataStore.recommendationStore.state
            switch state.phase {
            case .ready:
            return WatchRecommendationSnapshot(
                state: .available,
                    generatedAt: dataStore.recommendationStore.state.generatedAt?.date,
                    orderedEventIDs: state.eventIDs.map(\.intValue)
            )
        case .loading:
            return WatchRecommendationSnapshot(
                state: .loading,
                generatedAt: nil,
                orderedEventIDs: []
            )
            default:
            return WatchRecommendationSnapshot(
                state: .failed,
                generatedAt: nil,
                orderedEventIDs: []
            )
        }
    }

    private func makeFriendSnapshot() -> WatchFriendSnapshot {
        let updatedAt = profileStore.syncStore.lastSuccessfulRefreshDate
        if updatedAt != nil || !profileStore.acceptedFriendProfiles.isEmpty {
            return WatchFriendSnapshot(state: .available, updatedAt: updatedAt)
        }
        switch profileStore.accountStatus {
        case .checking:
            return WatchFriendSnapshot(state: .loading, updatedAt: nil)
        case .available, .local, .unavailable:
            return WatchFriendSnapshot(state: .unavailable, updatedAt: nil)
        }
    }

    private func watchFestivalDataSource(
        from source: FestivalDataSource
    ) -> WatchFestivalDataSource {
        switch source {
        case .remote:
            return .remote
        case .cache:
            return .cache
        case .staleCache:
            return .staleCache
        case .bundledBackup, .bundledArchive, .bundledExperiment, .screenshot, .preview:
            return .bundledBackup
        }
    }
}

@MainActor
private final class WatchSnapshotSender: NSObject, WCSessionDelegate {
    private struct PendingSnapshot {
        let data: Data
        let revision: UInt64
    }

    private let session: WCSession?
    private var pendingSnapshot: PendingSnapshot?
    private var retryTask: Task<Void, Never>?

    override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
    }

    deinit {
        retryTask?.cancel()
    }

    func start() {
        guard let session else {
            AppLog.watchSync.info("WatchConnectivity is unavailable on this device")
            return
        }
        session.delegate = self
        session.activate()
    }

    func enqueue(data: Data, revision: UInt64) {
        pendingSnapshot = PendingSnapshot(data: data, revision: revision)
        guard let session else {
            return
        }
        if session.activationState == .activated {
            flushPendingSnapshot()
        } else {
            session.activate()
        }
    }

    private func flushPendingSnapshot() {
        guard let session, session.activationState == .activated,
              let pendingSnapshot
        else {
            return
        }

        do {
            try session.updateApplicationContext([
                WatchSnapshotTransport.applicationContextKey: pendingSnapshot.data
            ])
            if self.pendingSnapshot?.revision == pendingSnapshot.revision {
                self.pendingSnapshot = nil
            }
            AppLog.watchSync.info(
                "Enqueued Watch snapshot revision \(pendingSnapshot.revision)"
            )
        } catch {
            AppLog.watchSync.error(
                "Could not enqueue Watch snapshot revision \(pendingSnapshot.revision): \(error.localizedDescription, privacy: .public)"
            )
            if let watchError = error as? WCError,
               watchError.code == .payloadTooLarge
            {
                self.pendingSnapshot = nil
            } else {
                scheduleRetry()
            }
        }
    }

    private func scheduleRetry() {
        guard retryTask == nil, pendingSnapshot != nil else {
            return
        }
        retryTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer { retryTask = nil }
            for delay in [1, 3, 10] {
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return
                }
                guard !Task.isCancelled, pendingSnapshot != nil else {
                    return
                }
                if session?.activationState == .activated {
                    flushPendingSnapshot()
                } else {
                    session?.activate()
                }
                if pendingSnapshot == nil {
                    return
                }
            }
            AppLog.watchSync.error(
                "Stopped retrying the pending Watch snapshot after three attempts"
            )
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            if let error {
                AppLog.watchSync.error(
                    "WatchConnectivity activation failed: \(error.localizedDescription, privacy: .public)"
                )
                self?.scheduleRetry()
                return
            }
            AppLog.watchSync.info(
                "WatchConnectivity activation completed with state \(activationState.rawValue)"
            )
            self?.flushPendingSnapshot()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        AppLog.watchSync.info("WatchConnectivity session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor [weak self] in
            AppLog.watchSync.info("WatchConnectivity session deactivated; reactivating")
            self?.session?.activate()
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.flushPendingSnapshot()
        }
    }
}

#endif
