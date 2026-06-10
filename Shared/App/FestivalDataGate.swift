import Foundation
import SwiftUI

struct FestivalDataGate<Content: View>: View {
    @EnvironmentObject private var dataStore: DataStore

    let content: () -> Content

    var body: some View {
        switch dataStore.festivalData {
        case .loading:
            FestivalDataLoadingView()
                .task {
                    await dataStore.loadFestivalContentForAppLaunch()
                }
        case .failure(let reason):
            FestivalDataUnavailableView(
                reason: reason
            ) {
                Task {
                    await dataStore.loadOrRefreshFestivalData()
                }
            }
        case .success(let festivalData):
            content()
                .environment(\.festivalData, festivalData)
                .task {
                    await dataStore.loadFestivalContentForAppLaunch()
                }
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
    let retry: () -> Void

    private static let festivalWebsiteURL = URL(
        string: "https://www.rudolstadt-festival.de/"
    )!

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

                if reason.showsFestivalWebsiteButton {
                    Link(destination: Self.festivalWebsiteURL) {
                        Label(
                            "data.unavailable.open_festival_website",
                            systemImage: "safari"
                        )
                    }
                    .buttonStyle(.bordered)
                }
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
