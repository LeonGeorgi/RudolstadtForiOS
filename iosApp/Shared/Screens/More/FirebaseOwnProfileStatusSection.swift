#if os(iOS)
import SwiftUI
import RudolstadtCore

struct FirebaseOwnProfileStatusSection: View {
    @ObservedObject var store: FirebaseOwnProfileStore

    var body: some View {
        if store.state.uid != nil {
            signedInSection
        }
    }

    private var signedInSection: some View {
        Section {
            LabeledContent("profile.sync.account", value: NSLocalizedString("profile.sync.signed_in", comment: ""))
            Text(LocalizedStringKey(store.state.phase.localizationKey))
            if let problem = store.state.problem {
                Text(LocalizedStringKey(problem.localizationKey)).foregroundStyle(.red)
            }
            Button("profile.sync.retry") { store.controller.retry() }
        } header: { Text("profile.sync.title") }
        footer: { Text("profile.sync.footer") }
    }
}
#endif
