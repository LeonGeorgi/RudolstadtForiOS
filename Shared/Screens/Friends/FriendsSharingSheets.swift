#if os(iOS)
import SwiftUI

struct InviteLinkShareSheetView: View {
    let profile: FestivalProfileStore

    @Environment(\.dismiss) private var dismiss
    @State private var inviteURL: URL?
    @State private var errorMessage: String?
    @State private var reloadToken = UUID()

    var body: some View {
        NavigationStack {
            Form {
                Section("friends.privacy.section") {
                    Text("friends.privacy.body")
                }
                Section {
                    if let inviteURL {
                        ShareLink(item: inviteURL) {
                            Label("friends.share_invite_link", systemImage: "square.and.arrow.up")
                        }
                    } else if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                        Button("friends.try_again") {
                            reloadToken = UUID()
                        }
                    } else {
                        ProgressView("friends.setup.connect.preparing")
                    }
                }
            }
            .navigationTitle("friends.invite.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("friends.done") {
                        dismiss()
                    }
                }
            }
        }
        .task(id: reloadToken) {
            inviteURL = nil
            errorMessage = nil
            do {
                let url = try await profile.prepareOneTimeShareURL()
                guard !Task.isCancelled else { return }
                inviteURL = url
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
        }
    }
}
#endif
