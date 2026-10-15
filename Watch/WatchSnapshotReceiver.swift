import Foundation
import WatchConnectivity
import WidgetKit

@MainActor
final class WatchSnapshotReceiver: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var state = WatchSnapshotState.loading

    nonisolated private let repository: WatchSnapshotRepository
    nonisolated private let importPipeline = WatchSnapshotImportPipeline()
    nonisolated private let activationGate = WatchSessionActivationGate()
    private let session: WCSession?

    init(
        repository: WatchSnapshotRepository = .live(
            expectedFestivalYear: FestivalConfiguration.year
        ),
        session: WCSession? = WCSession.isSupported() ? .default : nil
    ) {
        self.repository = repository
        self.session = session
        super.init()

        enqueueInitialLoad()
        session?.delegate = self
        if session?.activationState == .activated {
            activationGate.signal(.activated)
        }
        session?.activate()
    }

    deinit {
        importPipeline.suspendAndCancelAll()
    }

    func drainPendingContent() async {
        let lease = importPipeline.beginDrain()
        enqueueStoredLoadIfNeeded()
        await withTaskCancellationHandler {
            await performBackgroundDrain()
            importPipeline.endDrain(lease, cancelled: false)
        } onCancel: {
            self.importPipeline.endDrain(lease, cancelled: true)
        }
    }

    private func performBackgroundDrain() async {
        guard let session else {
            AppLog.watchSync.error(
                "Could not handle Watch background transfer because WatchConnectivity is unavailable"
            )
            return
        }

        activationGate.prepareForActivation()
        if session.activationState != .activated {
            session.activate()
            switch await activationGate.wait() {
            case .activated:
                break
            case .failed:
                enqueueApplicationContextIfPresent(session.receivedApplicationContext)
                if Task.isCancelled {
                    await drainCancelledImports()
                } else {
                    await importPipeline.drain()
                }
                return
            case .cancelled:
                await drainCancelledImports()
                return
            }
        }
        enqueueApplicationContextIfPresent(session.receivedApplicationContext)

        var consecutiveQuiescentChecks = 0
        while consecutiveQuiescentChecks < 2 {
            if Task.isCancelled {
                await drainCancelledImports()
                return
            }
            await importPipeline.drain()
            if session.hasContentPending || !importPipeline.isEmpty {
                consecutiveQuiescentChecks = 0
            } else {
                consecutiveQuiescentChecks += 1
            }
            guard consecutiveQuiescentChecks < 2 else {
                break
            }
            do {
                try await Task.sleep(for: .milliseconds(75))
            } catch is CancellationError {
                await drainCancelledImports()
                return
            } catch {
                AppLog.watchSync.error(
                    "WatchConnectivity background drain failed: \(error.localizedDescription, privacy: .public)"
                )
                return
            }
        }
        AppLog.watchSync.info("Completed WatchConnectivity background drain")
    }

    func refreshFreshness() async {
        importPipeline.resumeIntake()
        enqueueStoredLoadIfNeeded()
        enqueueApplicationContextIfPresent(session?.receivedApplicationContext ?? [:])
        enqueueStateRefresh()
        await importPipeline.drain()
    }

    private func enqueueStoredLoadIfNeeded() {
        guard case .loading = state.availability else {
            return
        }
        enqueueInitialLoad()
    }

    private func enqueueInitialLoad() {
        let repository = repository
        importPipeline.enqueue { [repository, receiver = self] in
            let loadedState = await repository.ensureLoaded()
            await receiver.applyLoadedState(loadedState)
        }
    }

    private func applyLoadedState(_ loadedState: WatchSnapshotState) {
        state = loadedState
        logStoredState(loadedState)
        enqueueApplicationContextIfPresent(session?.receivedApplicationContext ?? [:])
    }

    private func enqueueStateRefresh() {
        let repository = repository
        importPipeline.enqueue { [repository, receiver = self] in
            let updatedState = await repository.currentState()
            await receiver.applyCurrentState(updatedState)
        }
    }

    private func applyCurrentState(_ updatedState: WatchSnapshotState) {
        state = updatedState
    }

    private func enqueueApplicationContextIfPresent(
        _ applicationContext: [String: Any]
    ) {
        guard let value = applicationContext[
            WatchSnapshotTransport.applicationContextKey
        ] else {
            return
        }
        enqueueImport(value as? Data ?? Data())
    }

    private nonisolated func enqueueImport(_ data: Data) {
        let repository = repository
        importPipeline.enqueue { [repository, receiver = self] in
            let acceptance = await repository.accept(data)
            let updatedState = await repository.currentState()
            await receiver.apply(acceptance, state: updatedState)
        }
    }

    private func apply(
        _ acceptance: WatchSnapshotAcceptance,
        state updatedState: WatchSnapshotState
    ) {
        state = updatedState
        log(acceptance)
        if case .stored = acceptance {
            WidgetCenter.shared.reloadTimelines(
                ofKind: WatchWidgetKind.nextEvent
            )
        }
    }

    private func drainCancelledImports() async {
        await importPipeline.drain()
        AppLog.watchSync.info("Cancelled WatchConnectivity background drain")
    }

    private func logStoredState(_ state: WatchSnapshotState) {
        switch state.availability {
        case .loading:
            break
        case .available:
            AppLog.watchSync.info("Loaded the confirmed Watch snapshot")
        case .stale:
            AppLog.watchSync.info("Loaded a stale confirmed Watch snapshot")
        case .unavailable(let reason):
            switch reason {
            case .noSnapshot:
                AppLog.watchSync.debug("No confirmed Watch snapshot is stored yet")
            case .incompatibleStoredSchema(let received, let supported):
                AppLog.watchSync.error(
                    "Stored Watch snapshot schema \(received) is incompatible with supported schema \(supported)"
                )
            case .wrongStoredFestivalYear(let received, let expected):
                AppLog.watchSync.error(
                    "Stored Watch snapshot festival year \(received) does not match \(expected)"
                )
            case .disallowedStoredEnvironment:
                AppLog.watchSync.error(
                    "Stored Watch snapshot belongs to a non-production environment"
                )
            case .corruptStoredSnapshot:
                AppLog.watchSync.error("Stored Watch snapshot is corrupt")
            case .invalidIncomingSnapshot:
                AppLog.watchSync.error("Incoming Watch snapshot was invalid")
            case .readFailure:
                AppLog.watchSync.error("Could not read the stored Watch snapshot")
            case .persistenceFailure:
                AppLog.watchSync.error("Could not persist the Watch snapshot")
            }
        }
    }

    private func log(_ acceptance: WatchSnapshotAcceptance) {
        switch acceptance {
        case .stored(let revision):
            AppLog.watchSync.info(
                "Confirmed Watch snapshot revision \(revision) in the shared store"
            )
        case .ignored(let rejection):
            AppLog.watchSync.debug(
                "Ignored Watch snapshot: \(self.logDescription(for: rejection), privacy: .public)"
            )
        case .rejected(let rejection):
            AppLog.watchSync.error(
                "Rejected Watch snapshot: \(self.logDescription(for: rejection), privacy: .public)"
            )
        case .storageUnavailable:
            AppLog.watchSync.error(
                "Could not verify the stored Watch snapshot; skipped replacement"
            )
        case .persistenceFailed:
            AppLog.watchSync.error(
                "Could not persist Watch snapshot; retained the last confirmed revision"
            )
        }
    }

    private func logDescription(
        for rejection: WatchSnapshotRejection
    ) -> String {
        switch rejection {
        case .payloadTooLarge:
            return "payload too large"
        case .corrupt:
            return "corrupt payload"
        case .incompatibleSchema(let received, let supported):
            return "schema \(received), supported \(supported)"
        case .wrongFestivalYear(let received, let expected):
            return "festival year \(received), expected \(expected)"
        case .disallowedEnvironment(let environment):
            return "disallowed environment \(environment)"
        case .duplicateRevision(let revision):
            return "duplicate revision \(revision)"
        case .olderRevision(let received, let current):
            return "older revision \(received), current \(current)"
        case .invalidPayload:
            return "invalid payload invariants"
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let applicationContext = session.receivedApplicationContext
        if let value = applicationContext[
            WatchSnapshotTransport.applicationContextKey
        ] {
            enqueueImport(value as? Data ?? Data())
        }
        let errorDescription = error?.localizedDescription
        let activationRawValue = activationState.rawValue
        activationGate.signal(
            error == nil && activationState == .activated ? .activated : .failed
        )
        Task { @MainActor in
            if let errorDescription {
                AppLog.watchSync.error(
                    "WatchConnectivity activation failed on Watch: \(errorDescription, privacy: .public)"
                )
                return
            }
            AppLog.watchSync.info(
                "WatchConnectivity activated on Watch with state \(activationRawValue)"
            )
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let value = applicationContext[
            WatchSnapshotTransport.applicationContextKey
        ] else {
            return
        }
        enqueueImport(value as? Data ?? Data())
    }
}

private enum WatchSessionActivationOutcome: Sendable {
    case activated
    case failed
    case cancelled
}

private final class WatchSessionActivationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var outcome: WatchSessionActivationOutcome?
    private var waiters: [
        UUID: CheckedContinuation<WatchSessionActivationOutcome, Never>
    ] = [:]
    private var cancelledWaiterIDs = Set<UUID>()

    func prepareForActivation() {
        lock.lock()
        outcome = nil
        lock.unlock()
    }

    func signal(_ outcome: WatchSessionActivationOutcome) {
        lock.lock()
        self.outcome = outcome
        let continuations = Array(waiters.values)
        waiters.removeAll()
        lock.unlock()
        continuations.forEach { $0.resume(returning: outcome) }
    }

    func wait() async -> WatchSessionActivationOutcome {
        let waiterID = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                lock.lock()
                let immediateOutcome: WatchSessionActivationOutcome?
                if cancelledWaiterIDs.remove(waiterID) != nil {
                    immediateOutcome = .cancelled
                } else if let outcome {
                    immediateOutcome = outcome
                } else {
                    waiters[waiterID] = continuation
                    immediateOutcome = nil
                }
                lock.unlock()
                if let immediateOutcome {
                    continuation.resume(returning: immediateOutcome)
                }
            }
        } onCancel: {
            self.cancel(waiterID: waiterID)
        }
    }

    private func cancel(waiterID: UUID) {
        lock.lock()
        let continuation = waiters.removeValue(forKey: waiterID)
        if continuation == nil && outcome == nil {
            cancelledWaiterIDs.insert(waiterID)
        }
        lock.unlock()
        continuation?.resume(returning: .cancelled)
    }
}
