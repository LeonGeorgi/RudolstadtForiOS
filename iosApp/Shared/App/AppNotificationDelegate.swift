#if os(iOS)
import UIKit
import UserNotifications

/// Handles the app's local news notifications independently of profile synchronization.
final class AppNotificationDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            NewsNotificationNavigationController.shared.requestOpeningNewsItem(from: response)
            completionHandler()
        }
    }
}
#endif
