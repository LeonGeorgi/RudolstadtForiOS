#if os(iOS)
import CloudKit
import UIKit
import UserNotifications

@MainActor
final class CloudKitShareAcceptanceController {
    static let shared = CloudKitShareAcceptanceController()

    weak var profileStore: FestivalProfileStore?

    private init() {}

    func accept(metadata: CKShare.Metadata) async {
        await profileStore?.acceptShare(metadata: metadata)
    }

    func handleRemoteNotification() async {
        await profileStore?.refreshFromCloud(reason: "remote-notification")
    }
}

final class CloudKitShareAppDelegate: UIResponder, UIApplicationDelegate,
                                      UNUserNotificationCenterDelegate
{
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        AppLog.sync.info("Requested remote notification registration for CloudKit sync")
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        AppLog.sync.info(
            "Registered for remote notifications with device token length \(deviceToken.count)"
        )
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AppLog.sync.error(
            "Remote notification registration failed: \(error.localizedDescription, privacy: .public)"
        )
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let keys = userInfo.keys.map { String(describing: $0) }.sorted().joined(separator: ", ")
        AppLog.sync.info(
            "Received remote notification for CloudKit sync with keys [\(keys, privacy: .public)]"
        )
        Task { @MainActor in
            await CloudKitShareAcceptanceController.shared.handleRemoteNotification()
            completionHandler(.newData)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            NewsNotificationNavigationController.shared.requestOpeningNewsItem(
                from: response
            )
            completionHandler()
        }
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = CloudKitShareSceneDelegate.self
        }
        return configuration
    }
}

final class CloudKitShareSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            await CloudKitShareAcceptanceController.shared.accept(
                metadata: cloudKitShareMetadata
            )
        }
    }
}
#endif
