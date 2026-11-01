#if os(iOS)
import CloudKit
import OSLog
import SwiftUI
import UIKit

struct CloudSharingControllerView: UIViewControllerRepresentable {
    let share: CKShare

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(
            share: share,
            container: CKContainer(identifier: "iCloud.de.leongeorgi.RudolstadtForiOS")
        )
        controller.availablePermissions = [.allowPrivate, .allowReadOnly]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UICloudSharingController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: Error
        ) {
            AppLog.sync.error(
                "Cloud sharing controller failed to save share: \(error.localizedDescription, privacy: .public)"
            )
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            friendsLocalizedString("friends.cloud_share.title")
        }
    }
}

struct CloudKitInviteShareSheetView: UIViewControllerRepresentable {
    let profile: FestivalProfileStore

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let itemProvider = NSItemProvider()
        itemProvider.registerCKShare(
            container: CKContainer(identifier: "iCloud.de.leongeorgi.RudolstadtForiOS"),
            allowedSharingOptions: CKAllowedSharingOptions(
                allowedParticipantPermissionOptions: .readOnly,
                allowedParticipantAccessOptions: .specifiedRecipientsOnly
            )
        ) {
            try await profile.prepareShare()
        }

        let configuration = UIActivityItemsConfiguration(itemProviders: [itemProvider])
        configuration.metadataProvider = { key in
            if key == .title {
                return friendsLocalizedString("friends.cloud_share.title")
            }
            if key == .collaborationModeRestrictions {
                return [
                    UIActivityViewController.CollaborationModeRestriction(
                        disabledMode: .sendCopy
                    )
                ]
            }
            return nil
        }

        return UIActivityViewController(activityItemsConfiguration: configuration)
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
#endif
