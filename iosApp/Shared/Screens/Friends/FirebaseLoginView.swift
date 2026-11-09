#if os(iOS)
import AuthenticationServices
import CryptoKit
import RudolstadtCore
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct FirebaseLoginView: View {
    @ObservedObject var store: FirebaseFriendsStore
    @ObservedObject private var keys: KotlinStateStore<AccountKeyState>
    @ObservedObject private var deletion: KotlinStateStore<AccountDeletionState>
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var emailFocused: Bool
    @State private var email = ""
    @State private var link = ""
    @State private var accountKey = ""
    @State private var nonce = ""
    @State private var scanning = false
    @State private var method: Method?
    @State private var editingEmail = false
    @State private var showsManualLink = false
    private let isFriendsTab: Bool

    private enum Method: Hashable { case email, key }

    init(store: FirebaseFriendsStore, isFriendsTab: Bool) {
        self.store = store
        self.keys = store.keys
        self.deletion = store.deletion
        self.isFriendsTab = isFriendsTab
    }

    private var busy: Bool { store.state.busy || keys.state.busy || keys.state.loading || deletion.state.busy || deletion.state.pending }
    private var emailAddress: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var manualLink: String { link.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var emailConfirmation: EmailLinkDelivery? {
        guard !editingEmail, store.state.loginLink == nil else { return nil }
        return store.state.emailDelivery
    }

    var body: some View {
        loginContent
        .tint(.rudolstadt)
        .font(.body)
        .onChange(of: store.state.loginLink, initial: true) { _, value in
            guard value != nil else { return }
            if let delivery = store.state.emailDelivery { email = delivery.recipient }
            method = .email
        }
        .onChange(of: store.state.emailDelivery?.revision) { _, revision in
            guard revision != nil else { return }
            editingEmail = false
            showsManualLink = false
            link = ""
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.hideKey(); accountKey = ""; link = "" }
        }
        .onDisappear { store.hideKey(); accountKey = ""; link = "" }
    }

    private var loginContent: some View {
        Group {
            if keys.state.displayedKey != nil {
                FirebaseAccountKeyContent(store: store).navigationTitle("account.key.your_key")
            } else if method == .email { emailScreen }
            else if method == .key { keyForm }
            else { options.navigationTitle("account.login") }
        }
        .navigationBarTitleDisplayMode(method == nil && keys.state.displayedKey == nil ? .large : .inline)
        .navigationBarBackButtonHidden(method != nil)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if method != nil {
                    Button("account.back", systemImage: "chevron.backward", action: goBack)
                        .disabled(busy)
                }
            }
        }
    }

    private var options: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(LocalizedStringKey(isFriendsTab ? "account.login.friends_intro" : "account.login.intro"))
                    .foregroundStyle(.secondary)
                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        nonce = UUID().uuidString + UUID().uuidString
                        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
                            store.signInWithApple(credential, nonce: nonce)
                        case .failure(let error): store.appleSignInFailed(error)
                        }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .whiteOutline)
                    .clipShape(Capsule())
                    .frame(height: 50)
                    FirebaseGoogleSignInButton { store.signInWithGoogle() }
                    FirebaseAccountButton(title: "account.login.email") { method = .email }
                }
                .disabled(busy || !FirebaseFriendsRuntime.isEnabled)
                VStack(alignment: .leading, spacing: 8) {
                    Text("account.login.without_email")
                        .font(.subheadline).foregroundStyle(.secondary)
                    VStack(spacing: 0) {
                        accountOption("account.login.anonymous") { store.createKeyAccount() }
                        Divider().padding(.leading, 16)
                        accountOption("account.key.sign_in") { method = .key }
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    .disabled(busy || !FirebaseFriendsRuntime.isEnabled)
                }
                feedback
                VStack(alignment: .leading, spacing: 8) {
                    Text("account.login.local_hint").foregroundStyle(.secondary)
                    if let url = URL(string: "https://festival.leongeorgi.de/privacy.html") {
                        Link("account.privacy", destination: url)
                    }
                }
                .font(.footnote)
            }
            .padding(24)
            .frame(maxWidth: 540, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func accountOption(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emailScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let delivery = emailConfirmation {
                    emailSent(delivery)
                    manualLinkEntry(recipient: delivery.recipient)
                } else {
                    emailForm
                    if store.state.loginLink == nil { manualLinkEntry(recipient: emailAddress) }
                }
                feedback
            }
            .padding(.horizontal, 24).padding(.top, 48).padding(.bottom, 24)
            .frame(maxWidth: 540).frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("account.login.email")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { link = "" }
    }

    private var emailForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("firebase.friends.email").font(.subheadline.weight(.medium)).accessibilityHidden(true)
                TextField(
                    "firebase.friends.email", text: $email,
                    prompt: Text(verbatim: "name@example.com")
                )
                .textContentType(.emailAddress).keyboardType(.emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($emailFocused)
                .modifier(FirebaseEmailInputStyle())
                .disabled(busy)
            }
            if let loginLink = store.state.loginLink {
                Text("firebase.friends.confirm_email").font(.subheadline).foregroundStyle(.secondary)
                emailAction("firebase.friends.finish_email") { finishEmail(recipient: emailAddress, link: loginLink) }
                    .disabled(emailAddress.isEmpty || busy)
                Button("account.login.request_new_link") {
                    editEmailAddress()
                    store.controller.dismissEmailLink()
                }
                .disabled(busy)
            } else {
                Text("account.login.email_hint").font(.subheadline).foregroundStyle(.secondary)
                emailAction("firebase.friends.send_email") {
                    emailFocused = false
                    store.controller.sendEmail(email: emailAddress)
                }
                .disabled(emailAddress.isEmpty || busy)
            }
        }
    }

    private func emailSent(_ delivery: EmailLinkDelivery) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge")
                .font(.largeTitle)
                .foregroundStyle(Color.rudolstadt)
                .padding(16)
                .background(Color.rudolstadt.opacity(0.1), in: Circle())
                .accessibilityHidden(true)
            Text(LocalizedStringKey(delivery.isResend ? "account.login.link_resent" : "account.login.link_sent"))
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: delivery.recipient).font(.headline)
            Text("account.login.open_email_link").foregroundStyle(.secondary)
            VStack(spacing: 8) {
                FirebaseAccountButton(title: "account.login.resend_link") {
                    store.controller.sendEmail(email: delivery.recipient)
                }
                Button("account.login.change_email", action: editEmailAddress)
                    .frame(minHeight: 44)
            }
            .padding(.top, 8)
            .disabled(busy)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func manualLinkEntry(recipient: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup("account.login.link_manually", isExpanded: $showsManualLink) {
                VStack(spacing: 12) {
                    SecureField("firebase.friends.login_link", text: $link)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .modifier(FirebaseEmailInputStyle())
                        .privacySensitive()
                        .disabled(busy)
                    emailAction("firebase.friends.finish_email") { finishEmail(recipient: recipient, link: manualLink) }
                        .disabled(recipient.isEmpty || manualLink.isEmpty || busy)
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
            Text("account.login.manual_link_hint").font(.footnote).foregroundStyle(.secondary)
                .padding(.horizontal, 16)
        }
    }

    private func emailAction(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
    }

    private func finishEmail(recipient: String, link: String) {
        emailFocused = false
        store.controller.finishEmail(email: recipient, link: link)
    }

    private func editEmailAddress() {
        if let delivery = emailConfirmation { email = delivery.recipient }
        editingEmail = true
        showsManualLink = false
        link = ""
    }

    private func goBack() {
        if method == .email, emailConfirmation != nil {
            editEmailAddress()
        } else {
            method = nil
            accountKey = ""
            link = ""
            showsManualLink = false
        }
    }

    private var keyForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SecureField("account.key.input", text: $accountKey)
                    .textContentType(.password).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .modifier(FirebaseAccountInputStyle()).privacySensitive()
                FirebaseAccountButton(title: "account.key.sign_in") { store.signInWithKey(accountKey) }
                    .disabled(accountKey.isEmpty || busy)
                FirebaseAccountButton(title: "account.key.scan") { scanning = true }.disabled(busy)
                Text("account.key.management_footer").foregroundStyle(.secondary)
                feedback
            }
            .padding(.horizontal, 24).padding(.top, 48).padding(.bottom, 24)
            .frame(maxWidth: 540).frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("account.key.sign_in")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { accountKey = "" }
        .sheet(isPresented: $scanning) {
            NavigationStack {
                FirebaseFriendScanner { value in accountKey = value; scanning = false }
                    .navigationTitle("account.key.scan")
                    .toolbar { Button("account.cancel") { scanning = false } }
            }
        }
    }

    @ViewBuilder private var feedback: some View {
        if deletion.state.deleted { Text("account.delete.success") }
        if !FirebaseFriendsRuntime.isEnabled { Text("firebase.friends.unavailable").foregroundStyle(.secondary) }
        if busy { ProgressView().frame(maxWidth: .infinity) }
        if let error = store.state.error { Text(LocalizedStringKey(error.localizationKey)).foregroundStyle(.red) }
        if let error = keys.state.error { Text(LocalizedStringKey(error.localizationKey)).foregroundStyle(.red) }
    }


}

private struct FirebaseGoogleSignInButton: View {
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    private var dark: Bool { colorScheme == .dark }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("GoogleSignInLogo").resizable().scaledToFit()
                    .frame(width: 20, height: 20).accessibilityHidden(true)
                Text("firebase.friends.google")
                    .font(.custom("GoogleSans-Medium", size: 17, relativeTo: .body))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Color(white: dark ? 0.89 : 0.12))
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(dark ? Color(red: 19 / 255, green: 19 / 255, blue: 20 / 255) : .white, in: Capsule())
            .overlay { Capsule().strokeBorder(Color(red: dark ? 142 / 255 : 116 / 255,
                                                    green: dark ? 145 / 255 : 119 / 255,
                                                    blue: dark ? 143 / 255 : 117 / 255), lineWidth: 1) }
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
    }
}

struct FirebaseAccountButton: View {
    let title: LocalizedStringKey
    var action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title).foregroundStyle(isEnabled ? Color.rudolstadt : .secondary)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.large)
        .tint(.secondary)
    }
}

private struct FirebaseAccountInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.body).padding(.horizontal, 8).frame(minHeight: 52)
            .overlay(alignment: .bottom) { Divider().padding(.horizontal, 8) }
    }
}

private struct FirebaseEmailInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(.horizontal, 16).padding(.vertical, 12).frame(minHeight: 52)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 17))
    }
}

struct FirebaseAuthenticationGate<Content: View>: View {
    @ObservedObject var store: FirebaseFriendsStore
    @ObservedObject private var deletion: KotlinStateStore<AccountDeletionState>
    @ObservedObject private var keys: KotlinStateStore<AccountKeyState>
    @State private var showingLogin = false
    private let isFriendsTab: Bool
    let content: () -> Content

    init(store: FirebaseFriendsStore, isFriendsTab: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.store = store
        self.deletion = store.deletion
        self.keys = store.keys
        self.isFriendsTab = isFriendsTab
        self.content = content
    }

    var body: some View {
        if !deletion.state.pending && (store.state.uid == nil || keys.state.uid != store.state.uid || (showingLogin && keys.state.displayedKey != nil)) {
            FirebaseLoginView(store: store, isFriendsTab: isFriendsTab).onAppear { showingLogin = true }
        } else { content().onAppear { showingLogin = false } }
    }
}

struct FirebaseAccountKeyContent: View {
    @ObservedObject var store: FirebaseFriendsStore
    @ObservedObject private var keys: KotlinStateStore<AccountKeyState>
    @Environment(\.scenePhase) private var scenePhase

    init(store: FirebaseFriendsStore) { self.store = store; self.keys = store.keys }

    var body: some View {
        ScrollView {
            if scenePhase == .active, let key = keys.state.displayedKey {
                VStack(alignment: .leading, spacing: 24) {
                    Text(key).font(.body.monospaced()).textSelection(.enabled)
                    QRCodeImageCard(value: key).frame(width: 240).frame(maxWidth: .infinity)
                    FirebaseAccountButton(title: "account.key.copy") {
                        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: key]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
                    }
                    Text("account.key.backup_warning").font(.footnote).foregroundStyle(.secondary)
                    FirebaseAccountButton(title: "account.key.done") { store.hideKey() }
                }
                .padding(24)
                .frame(maxWidth: 540, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .privacySensitive()
    }
}
#endif
