import Foundation

final class WatchSnapshotImportPipeline: @unchecked Sendable {
    struct DrainLease: Hashable, Sendable {
        fileprivate let id: UUID
    }

    private let lock = NSLock()
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var tailTask: Task<Void, Never>?
    private var acceptsNewTasks = true
    private var activeDrainLeaseIDs = Set<UUID>()

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return tasks.isEmpty
    }

    @discardableResult
    func enqueue(_ operation: @escaping @Sendable () async -> Void) -> Bool {
        let taskID = UUID()
        lock.lock()
        guard acceptsNewTasks else {
            lock.unlock()
            return false
        }
        let predecessor = tailTask
        let task = Task {
            if let predecessor {
                await predecessor.value
            }
            guard !Task.isCancelled else {
                return
            }
            await operation()
        }
        tasks[taskID] = task
        tailTask = task
        lock.unlock()

        Task { [weak self] in
            await task.value
            self?.remove(taskID: taskID)
        }
        return true
    }

    func drain() async {
        while true {
            let currentTasks = taskSnapshot()
            guard !currentTasks.isEmpty else {
                return
            }
            for (taskID, task) in currentTasks {
                await task.value
                remove(taskID: taskID)
            }
        }
    }

    func resumeIntake() {
        lock.lock()
        acceptsNewTasks = true
        lock.unlock()
    }

    func beginDrain() -> DrainLease {
        let lease = DrainLease(id: UUID())
        lock.lock()
        acceptsNewTasks = true
        activeDrainLeaseIDs.insert(lease.id)
        lock.unlock()
        return lease
    }

    func endDrain(_ lease: DrainLease, cancelled: Bool) {
        lock.lock()
        guard activeDrainLeaseIDs.remove(lease.id) != nil else {
            lock.unlock()
            return
        }
        let tasksToCancel: [Task<Void, Never>]
        if cancelled && activeDrainLeaseIDs.isEmpty {
            acceptsNewTasks = false
            tasksToCancel = Array(tasks.values)
        } else {
            tasksToCancel = []
        }
        lock.unlock()
        tasksToCancel.forEach { $0.cancel() }
    }

    func suspendAndCancelAll() {
        lock.lock()
        acceptsNewTasks = false
        activeDrainLeaseIDs.removeAll()
        let currentTasks = Array(tasks.values)
        lock.unlock()
        currentTasks.forEach { $0.cancel() }
    }

    private func taskSnapshot() -> [(taskID: UUID, task: Task<Void, Never>)] {
        lock.lock()
        defer { lock.unlock() }
        return tasks.map { (taskID: $0.key, task: $0.value) }
    }

    private func remove(taskID: UUID) {
        lock.lock()
        tasks.removeValue(forKey: taskID)
        if tasks.isEmpty {
            tailTask = nil
        }
        lock.unlock()
    }
}
