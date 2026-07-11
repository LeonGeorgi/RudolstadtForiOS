import Nuke
import SwiftUI

private enum SettingsFeatureFlags {
    static let showsCacheManagementActions = false
}

struct SettingsView: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var notificationPermissionController =
        NotificationPermissionController.shared
    @State private var isShowingClearCacheAlert = false
    @State private var isClearingCache = false
    @State private var isShowingCacheClearedAlert = false
    @State private var isShowingDeleteFestivalDataAlert = false
    @State private var isShowingFestivalDataDeletedAlert = false
    @State private var isShowingFestivalDataDeleteFailedAlert = false

    var useFlames: Binding<Bool> {
        Binding(
            get: { settings.likeIcon == "flame.fill" },
            set: { newValue in
                settings.likeIcon = newValue ? "flame.fill" : "heart.fill"
            }
        )
    }

    var showAISummaries: Binding<Bool> {
        Binding(
            get: { settings.aiSummaryEnabled },
            set: { newValue in
                settings.aiSummaryEnabled = newValue
            }
        )
    }

    var body: some View {
        List {
            Section {
                Button(action: handleNotificationSettingsAction) {
                    HStack {
                        Label("settings.notifications", systemImage: "bell.badge")
                        Spacer()
                        Text(notificationStatusLabel)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("settings.notifications.footer")
            }

            Toggle(isOn: showAISummaries) {
                Label("settings.show_ai_summaries", systemImage: "sparkles")
            }
            Toggle(isOn: useFlames) {
                Label("settings.use_flames", systemImage: settings.likeIcon)
            }
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Label("settings.language", systemImage: "globe")
                }
            }
            if SettingsFeatureFlags.showsCacheManagementActions {
                Button(role: .destructive) {
                    isShowingClearCacheAlert = true
                } label: {
                    Label("settings.clear_cache.button", systemImage: "trash")
                }
                .disabled(isClearingCache)

                Button(role: .destructive) {
                    isShowingDeleteFestivalDataAlert = true
                } label: {
                    Label(
                        "settings.delete_festival_data.button",
                        systemImage: "externaldrive.badge.xmark"
                    )
                }
            }

        }
        .font(.body)
        .listStyle(.insetGrouped)
        .navigationTitle("settings.title")
        .task(id: scenePhase) {
            guard scenePhase == .active else {
                return
            }
            await notificationPermissionController.refreshAuthorizationStatus()
        }
        .alert("settings.clear_cache.title", isPresented: $isShowingClearCacheAlert) {
            Button("settings.clear_cache.cancel", role: .cancel) {}
            Button("settings.clear_cache.confirm", role: .destructive) {
                clearCachedData()
            }
        } message: {
            Text("settings.clear_cache.message")
        }
        .alert("settings.clear_cache.done_title", isPresented: $isShowingCacheClearedAlert) {
            Button("settings.clear_cache.ok", role: .cancel) {}
        } message: {
            Text("settings.clear_cache.done_message")
        }
        .alert(
            "settings.delete_festival_data.title",
            isPresented: $isShowingDeleteFestivalDataAlert
        ) {
            Button("settings.delete_festival_data.cancel", role: .cancel) {}
            Button("settings.delete_festival_data.confirm", role: .destructive) {
                deleteFestivalData()
            }
        } message: {
            Text("settings.delete_festival_data.message")
        }
        .alert(
            "settings.delete_festival_data.done_title",
            isPresented: $isShowingFestivalDataDeletedAlert
        ) {
            Button("settings.delete_festival_data.ok", role: .cancel) {}
        } message: {
            Text("settings.delete_festival_data.done_message")
        }
        .alert(
            "settings.delete_festival_data.failed_title",
            isPresented: $isShowingFestivalDataDeleteFailedAlert
        ) {
            Button("settings.delete_festival_data.ok", role: .cancel) {}
        } message: {
            Text("settings.delete_festival_data.failed_message")
        }

    }

    private var notificationStatusLabel: LocalizedStringKey {
        switch notificationPermissionController.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            "settings.notifications.on"
        case .denied:
            "settings.notifications.off"
        case .notDetermined:
            "settings.notifications.activate"
        @unknown default:
            "settings.notifications.open"
        }
    }

    private func handleNotificationSettingsAction() {
        if notificationPermissionController.authorizationStatus == .notDetermined {
            settings.notificationPromptState = .systemPromptRequested
            Task {
                await notificationPermissionController.requestAuthorization()
                if notificationPermissionController.authorizationStatus == .notDetermined {
                    settings.notificationPromptState = .deferred
                }
            }
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func clearCachedData() {
        isClearingCache = true

        ArtistImageColorCache.shared.clearCache()
        URLCache.shared.removeAllCachedResponses()
        Nuke.DataLoader.sharedUrlCache.removeAllCachedResponses()
        ImagePipeline.shared.cache.removeAll(caches: [.all])
        ImageCache.shared.removeAll()

        Task { @MainActor in
            isClearingCache = false
            isShowingCacheClearedAlert = true
        }
    }

    private func deleteFestivalData() {
        if dataStore.deleteCachedFestivalData() {
            isShowingFestivalDataDeletedAlert = true
        } else {
            isShowingFestivalDataDeleteFailedAlert = true
        }
    }
}
