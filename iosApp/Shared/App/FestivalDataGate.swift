import Foundation
import SwiftUI

struct FestivalDataGate<Content: View>: View {
    @EnvironmentObject private var dataStore: DataStore
    @State private var loadAttempt = 0

    let content: () -> Content

    var body: some View {
        Group {
            switch dataStore.festivalData {
            case .loading:
                FestivalDataLoadingView()
            case .failure(let reason):
                FestivalDataUnavailableView(
                    reason: reason,
                    websiteURL: dataStore.metadata.officialLinks.first?.destination
                ) {
                    loadAttempt += 1
                }
            case .success(let festivalData):
                VStack(spacing: 0) {
                    ForEach(dataStore.metadata.notices) { notice in
                        VStack(spacing: 4) {
                            Text(notice.title.resolved()).font(.subheadline.weight(.semibold))
                            if let message = notice.message { Text(message.resolved()).font(.footnote) }
                        }
                        .foregroundStyle(notice.severity == .warning ? Color.black : Color.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal).padding(.vertical, 8).frame(maxWidth: .infinity)
                        .background(notice.severity == .warning ? Color.orange : Color.clear)
                    }

                    content()

                    // Reserve layout space outside the tab view so this notice cannot cover its tab bar.
                    if festivalData.omittedRecordCount > 0 {
                        Label("data.import.incomplete", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.background)
                    }
                }
                .environment(\.festivalData, festivalData)
                .environment(\.festivalEdition, dataStore.edition)
            }
        }
        .task(id: loadAttempt) {
            await dataStore.loadFestivalContentForAppLaunch()
        }
    }
}

private struct FestivalDataLoadingView: View {
    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .accessibilityLabel(Text("data.loading.progress"))

            VStack(spacing: 8) {
                Text("data.loading.title")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("data.loading.description")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private struct FestivalDataUnavailableView: View {
    let reason: FailureReason
    @State private var isShowingSettings = false

    let websiteURL: URL?
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: reason.iconName)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(reason.title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(reason.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button("data.unavailable.retry", action: retry)
                    .buttonStyle(.borderedProminent)

                if reason.showsFestivalWebsiteButton, let websiteURL {
                    Link(destination: websiteURL) {
                        Label(
                            "data.unavailable.open_festival_website",
                            systemImage: "safari"
                        )
                    }
                    .buttonStyle(.bordered)
                }
                Button("settings.title") { isShowingSettings = true }
            }
            .padding(.top, 4)

            Text(reason.localizedDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("archive.close") { isShowingSettings = false }
                        }
                    }
            }
        }
    }
}

private extension FailureReason {
    var iconName: String {
        switch self {
        case .noConnection:
            return "wifi.slash"
        case .apiNotResponding, .festivalServerError:
            return "server.rack"
        case .couldNotLoadFromFile:
            return "doc.badge.exclamationmark"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .noConnection:
            return "data.unavailable.no_connection.title"
        case .festivalServerError:
            return "data.unavailable.server_error.title"
        case .apiNotResponding, .couldNotLoadFromFile:
            return "data.unavailable.title"
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .noConnection:
            return "data.unavailable.no_connection.description"
        case .festivalServerError:
            return "data.unavailable.server_error.description"
        case .apiNotResponding, .couldNotLoadFromFile:
            return "data.unavailable.description"
        }
    }

    var localizedDescription: LocalizedStringKey {
        switch self {
        case .noConnection:
            return "data.unavailable.reason.no_connection"
        case .apiNotResponding:
            return "data.unavailable.reason.api_not_responding"
        case .festivalServerError:
            return "data.unavailable.reason.festival_server_error"
        case .couldNotLoadFromFile:
            return "data.unavailable.reason.could_not_load_file"
        }
    }

    var showsFestivalWebsiteButton: Bool {
        switch self {
        case .festivalServerError:
            return true
        case .noConnection, .apiNotResponding, .couldNotLoadFromFile:
            return false
        }
    }
}
