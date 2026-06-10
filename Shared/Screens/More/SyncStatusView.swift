#if os(iOS)
import SwiftUI

private func syncLocalizedString(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

struct SyncStatusView: View {
    @EnvironmentObject private var dataStore: DataStore
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var profileSync: FestivalProfileSyncStore

    @State private var isCheckingFestivalData = false

    var body: some View {
        List {
            Section {
                SyncStatusRow(
                    title: "sync.festival_data.row.program",
                    value: festivalDataSummaryText
                )
                SyncStatusRow(
                    title: "sync.festival_data.row.last_update",
                    value: festivalDataLastUpdateText
                )
                SyncStatusRow(
                    title: "sync.festival_data.row.status",
                    value: festivalDataStatusText,
                    valueColor: festivalDataStatusIsProblem ? .red : .secondary
                )

                Button {
                    checkFestivalData()
                } label: {
                    Label {
                        Text(LocalizedStringKey(
                            isCheckingFestivalData
                                ? "sync.festival_data.checking"
                                : "sync.festival_data.check_updates"
                        ))
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(isCheckingFestivalData)
            } header: {
                Text("sync.festival_data.section.title")
            } footer: {
                Text("sync.festival_data.footer")
            }

            Section {
                SyncStatusRow(title: "sync.row.icloud", value: profileSync.accountStatusText)
                SyncStatusRow(title: "sync.row.sync", value: profileSync.syncStatusText)
                SyncStatusRow(
                    title: "sync.row.last_successful_sync",
                    value: profileSync.lastSuccessfulRefreshText
                )

                Button {
                    Task {
                        await profile.refreshFromCloud()
                    }
                } label: {
                    Label("sync.refresh.button", systemImage: "arrow.clockwise")
                }
            } header: {
                Text("sync.section.title")
            } footer: {
                Text("sync.section.footer")
            }
        }
        .navigationTitle("more.sync.title")
    }

    private var festivalDataSummaryText: String {
        switch dataStore.festivalData {
        case .success(let festivalData):
            return String(
                format: syncLocalizedString("sync.festival_data.program.summary.format"),
                Int64(festivalData.artists.count),
                Int64(festivalData.events.count),
                Int64(festivalData.stages.count)
            )
        case .loading:
            return syncLocalizedString("sync.festival_data.program.loading")
        case .failure:
            return syncLocalizedString("sync.festival_data.program.unavailable")
        }
    }

    private var festivalDataStatusText: String {
        if let fallbackStatus = dataStore.festivalDataFallbackStatus {
            return fallbackStatusText(for: fallbackStatus)
        }

        guard dataStore.festivalDataLastDownloadDate != nil else {
            return syncLocalizedString("sync.festival_data.status.no_local_data")
        }

        return syncLocalizedString("sync.festival_data.status.downloaded")
    }

    private var festivalDataLastUpdateText: String {
        if let festivalDataLastDownloadDate = dataStore.festivalDataLastDownloadDate {
            return festivalDataLastDownloadDate.formatted(
                date: .abbreviated,
                time: .shortened
            )
        }

        if dataStore.isUsingBundledFestivalDataBackup {
            return syncLocalizedString("sync.festival_data.last_update.backup")
        }

        return syncLocalizedString("sync.festival_data.last_update.not_yet")
    }

    private var festivalDataStatusIsProblem: Bool {
        if dataStore.festivalDataFallbackStatus != nil {
            return true
        }

        if dataStore.isUsingBundledFestivalDataBackup {
            return true
        }

        switch dataStore.festivalData {
        case .failure:
            return true
        case .loading, .success:
            return false
        }
    }

    private func fallbackStatusText(for status: FestivalDataFallbackStatus) -> String {
        switch status.failure.owner {
        case .festivalSide:
            return syncLocalizedString("sync.festival_data.status.festival_problem")
        case .appSide:
            return syncLocalizedString("sync.festival_data.status.app_problem")
        case .connection:
            return syncLocalizedString("sync.festival_data.status.connection_problem")
        case .unknown:
            return syncLocalizedString("sync.festival_data.status.update_failed")
        }
    }

    private func checkFestivalData() {
        isCheckingFestivalData = true
        Task {
            await dataStore.loadOrRefreshFestivalData()
            isCheckingFestivalData = false
        }
    }
}

private extension FestivalProfileSyncStore {
    var accountStatusText: String {
        switch iCloudStatus {
        case .checking:
            return syncLocalizedString("sync.account.checking")
        case .available:
            return syncLocalizedString("sync.account.available")
        case .unavailable(let reason):
            return reason
        }
    }

    var syncStatusText: String {
        switch syncState {
        case .idle:
            return syncLocalizedString("sync.status.up_to_date")
        case .syncing:
            return syncLocalizedString("sync.status.syncing")
        case .error(let reason):
            return reason
        }
    }

    var lastSuccessfulRefreshText: String {
        guard let lastSuccessfulRefreshDate else {
            return syncLocalizedString("sync.last_successful.not_yet")
        }
        return lastSuccessfulRefreshDate.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }
}

private struct SyncStatusRow: View {
    let title: LocalizedStringKey
    let value: String
    var valueColor: Color = .secondary

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }
}
#endif
