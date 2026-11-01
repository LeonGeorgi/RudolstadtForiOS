import SwiftUI

@main
@MainActor
struct RudolstadtWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var snapshotReceiver = WatchSnapshotReceiver()

    var body: some Scene {
        WindowGroup {
            WatchRootView(receiver: snapshotReceiver)
                .task(id: scenePhase) {
                    guard scenePhase == .active else {
                        return
                    }
                    await snapshotReceiver.refreshFreshness()
                }
        }
        .backgroundTask(.watchConnectivity) {
            await snapshotReceiver.drainPendingContent()
        }
    }
}
