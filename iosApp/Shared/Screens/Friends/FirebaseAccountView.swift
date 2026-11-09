#if os(iOS)
import RudolstadtCore
import SwiftUI

struct FirebaseAccountKeyManagementView: View {
    @ObservedObject var store: FirebaseFriendsStore
    @ObservedObject private var keys: KotlinStateStore<AccountKeyState>
    @ObservedObject private var deletion: KotlinStateStore<AccountDeletionState>
    @Environment(\.scenePhase) private var scenePhase
    @State private var replacingKey = false

    init(store: FirebaseFriendsStore) {
        self.store = store
        self.keys = store.keys
        self.deletion = store.deletion
    }

    private var busy: Bool {
        store.state.busy || keys.state.busy || deletion.state.busy || deletion.state.pending
    }

    var body: some View {
        FirebaseAuthenticationGate(store: store) {
            if keys.state.isKeyAccount { keyManagementContent }
            else { Text("account.key.standalone_only") }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { store.hideKey() } }
    }

    private var keyManagementContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("account.key.management_footer").foregroundStyle(.secondary)
                FirebaseAccountButton(title: LocalizedStringKey(keys.state.hasKey ? "account.key.replace" : "account.key.add")) { replacingKey = true }
                .disabled(busy || keys.state.loading)
                Text("account.key.recovery_hint").foregroundStyle(.secondary)
                if keys.state.error != nil {
                    Button("account.key.retry") { store.refreshKey() }.disabled(busy || keys.state.loading)
                }
                if keys.state.loading { ProgressView() }
                if let error = keys.state.error { Text(LocalizedStringKey(error.localizationKey)).foregroundStyle(.red) }
            }
            .padding(24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("account.key.title")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: keys.state.uid) { store.refreshKey() }
        .sheet(isPresented: Binding(get: { keys.state.displayedKey != nil }, set: { if !$0 { store.hideKey() } })) {
            NavigationStack {
                FirebaseAccountKeyContent(store: store)
                    .navigationTitle("account.key.your_key")
            }
        }
        .alert("account.key.replace_title", isPresented: $replacingKey) {
            Button(LocalizedStringKey(keys.state.hasKey ? "account.key.replace" : "account.key.add")) { store.replaceKey() }
            Button("account.cancel", role: .cancel) {}
        } message: { Text("account.key.replace_warning") }
        .onDisappear { store.hideKey() }
    }
}
#endif
