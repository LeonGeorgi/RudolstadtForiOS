import Testing
import UserNotifications
@testable import Rudolstadt

@MainActor
struct NotificationPermissionPresentationTests {
    @Test
    func presentsPrePromptOnlyBeforeSystemDecisionAndBeforeDeferral() {
        #expect(
            NotificationPermissionController.shouldPresentPrePrompt(
                authorizationStatus: .notDetermined,
                promptState: .notPresented
            )
        )
        #expect(
            !NotificationPermissionController.shouldPresentPrePrompt(
                authorizationStatus: .notDetermined,
                promptState: .deferred
            )
        )
        #expect(
            !NotificationPermissionController.shouldPresentPrePrompt(
                authorizationStatus: .authorized,
                promptState: .notPresented
            )
        )
        #expect(
            !NotificationPermissionController.shouldPresentPrePrompt(
                authorizationStatus: .denied,
                promptState: .notPresented
            )
        )
    }
}
