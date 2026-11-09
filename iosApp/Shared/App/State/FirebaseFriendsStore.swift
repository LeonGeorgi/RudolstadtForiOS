#if os(iOS)
import AuthenticationServices
import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import Foundation
import GoogleSignIn
import RudolstadtCore
import Security
import CryptoKit
import UIKit

enum FirebaseFriendsRuntime {
    static let authDomain = FriendsConfiguration.shared.authDomain
    static var isEnabled: Bool {
        FestivalProfileStore.defaultCloudSyncEnabled
            && Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil
    }
    static func configure() {
        guard isEnabled, FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
    }
}

/// SwiftUI binding and native SDK composition; all friend workflow lives in Kotlin.
@MainActor
final class FirebaseFriendsStore: KotlinStateStore<FriendsState> {
    let controller: FriendsController
    let keys: KotlinStateStore<AccountKeyState>
    let deletion: KotlinStateStore<AccountDeletionState>
    private let deletionController: AccountDeletionController
    private let keyController: AccountKeyController
    private let transport: FirebaseFriendsTransport
    private var ownerObservation: StateSubscription?
    private var friendObservation: StateSubscription?
    private weak var archiveProfile: FestivalProfileStore?
    var invitationURL: URL? { state.ownInvite.flatMap(URL.init(string:)) }
    var accountEmail: String? { transport.accountEmail }
    var hasAccountProvider: Bool { transport.hasAccountProvider }
    var requiresAppleDeletionAuthorization: Bool { transport.requiresAppleDeletionAuthorization }

    init(profile: FestivalProfileStore) {
        FirebaseFriendsRuntime.configure()
        let transport = FirebaseFriendsTransport(enabled: FirebaseFriendsRuntime.isEnabled)
        let accountActions = AccountActionGate()
        let controller = FriendsController(edition: FestivalEdition.current.legacySelectionID, transport: transport, accountActions: accountActions)
        self.transport = transport
        self.controller = controller
        let keyController = AccountKeyController(transport: transport, accountActions: accountActions)
        self.keyController = keyController
        self.keys = KotlinStateStore(current: { keyController.current }, observe: keyController.observe)
        let deletionController = AccountDeletionController(transport: transport, profile: profile.firebaseOwnProfile.controller, accountActions: accountActions)
        self.deletionController = deletionController
        self.deletion = KotlinStateStore(current: { deletionController.current }, observe: deletionController.observe)
        super.init(current: { controller.current }, observe: controller.observe)
        friendObservation = controller.observe { [weak self, weak profile] state in
            profile?.friendProfilesStore.viewModel.restore(profiles: state.friends)
            profile?.syncStore.viewModel.sharing(shared: state.active, preparing: false, participants: Int32(state.friends.count))
            self?.archiveProfile?.friendProfilesStore.viewModel.restore(profiles: state.archiveFriends)
        }
        let source = profile.firebaseOwnProfile.controller
        let value = source.current
        controller.syncProfile(profile: value.profile, owner: value.uid, ready: value.phase == .ready)
        ownerObservation = source.observe { [weak controller] value in
            controller?.syncProfile(profile: value.profile, owner: value.uid, ready: value.phase == .ready)
        }
    }

    func showArchive(edition: String?, profile: FestivalProfileStore?) {
        if archiveProfile !== profile {
            archiveProfile?.friendProfilesStore.viewModel.restore(profiles: [])
            archiveProfile = profile
        }
        controller.showArchive(edition: edition)
        profile?.friendProfilesStore.viewModel.restore(profiles: controller.current.archiveFriends)
    }

    deinit {
        friendObservation?.cancel()
        ownerObservation?.cancel()
        Task { @MainActor [controller, keyController, deletionController] in controller.close(); keyController.close(); deletionController.close() }
    }

    @discardableResult
    func receive(_ url: URL) -> Bool {
        let value = url.absoluteString
        guard controller.receive(value: value) else { return false }
        let current = controller.current
        if current.uid == nil, current.loginLink == value, let delivery = current.emailDelivery {
            controller.finishEmail(email: delivery.recipient, link: value)
        }
        return true
    }

    func signInWithApple(_ credential: ASAuthorizationAppleIDCredential, nonce: String) {
        controller.authenticate { [transport] completed in
            transport.signInWithApple(credential, nonce: nonce) { _ = completed($0) }
        }
    }

    func signInWithGoogle() {
        controller.authenticate { [transport] completed in
            transport.signInWithGoogle { _ = completed($0) }
        }
    }

    func createKeyAccount() { keyController.createAccount() }
    func signInWithKey(_ key: String) { keyController.signIn(value: key) }
    func replaceKey() { keyController.replaceKey() }
    func hideKey() { keyController.hideKey() }
    func refreshKey() { keyController.refresh() }
    func deleteAccount() {
        keyController.hideKey()
        deletionController.deleteAccount { [transport] owner, completed in
            transport.prepareAccountDeletion(owner: owner) { _ = completed($0) }
        }
    }
    func retryDeletion() { deletionController.retry() }

    func appleSignInFailed(_ error: Error) {
        controller.authenticate { completed in
            _ = completed((error as? ASAuthorizationError)?.code == .canceled ? .cancelled : .failed)
        }
    }
}

final class FirebaseFriendsSubscription: NSObject, FriendsSubscription {
    private var dispose: (() -> Void)?
    init(_ dispose: @escaping () -> Void) { self.dispose = dispose }
    func cancel() { let action = dispose; dispose = nil; action?() }
}

final class FirebaseFriendsTransport: NSObject, FriendsTransport, AccountKeyTransport, AccountDeletionTransport {
    private let enabled: Bool
    init(enabled: Bool) { self.enabled = enabled }
    private var auth: Auth { Auth.auth() }
    private var database: Firestore { Firestore.firestore() }
    func accountHasProvider() -> Bool {
        guard enabled, let user = auth.currentUser else { return false }
        return user.email != nil || user.phoneNumber != nil || user.providerData.contains { $0.providerID != "firebase" }
    }
    var accountEmail: String? { enabled ? auth.currentUser?.email : nil }
    var hasAccountProvider: Bool {
        enabled && auth.currentUser?.providerData.contains { ["apple.com", "google.com", "password"].contains($0.providerID) } == true
    }
    var requiresAppleDeletionAuthorization: Bool {
        guard enabled, let user = auth.currentUser else { return false }
        return hasAppleProvider(user)
    }

    private func hasAppleProvider(_ user: User) -> Bool {
        user.providerData.contains { $0.providerID == "apple.com" }
    }

    private var appleDeletion: AppleAccountDeletionAuthorization?
    private var deletionRequests: FirebaseApp? {
        if let app = FirebaseApp.app(name: "AccountDeletionRequests") { return app }
        guard let main = FirebaseApp.app() else { return nil }
        FirebaseApp.configure(name: "AccountDeletionRequests", options: main.options)
        return FirebaseApp.app(name: "AccountDeletionRequests")
    }

    @MainActor
    func prepareAccountDeletion(owner: String, completed: @escaping (FriendsTransportError?) -> Void) {
        guard let user = auth.currentUser, user.uid == owner else { completed(.cancelled); return }
        guard hasAppleProvider(user) else { completed(nil); return }
        let authorization = AppleAccountDeletionAuthorization(owner: owner) { [weak self] error in
            self?.appleDeletion = nil
            completed(error)
        }
        appleDeletion = authorization
        authorization.start()
    }

    func signOutDeletedAccount(owner: String, completed: @escaping (FriendsTransportError?) -> Void) {
        if auth.currentUser?.uid == owner { signOut(completed: completed) } else { completed(nil) }
    }

    func secureKeyEntropy() -> String? {
        var bytes = [UInt8](repeating: 0, count: 20)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return nil }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    func signInCustomToken(token: String, expectedUID: String?, completed: @escaping (FriendsTransportError?) -> Void) {
        guard enabled, auth.currentUser?.uid == expectedUID else { completed(.cancelled); return }
        auth.signIn(withCustomToken: token) { _, error in completed(error?.friendsTransportError) }
    }

    func observeAccount(changed: @escaping (String?) -> Void) -> any FriendsSubscription {
        guard enabled else { return FirebaseFriendsSubscription {} }
        let auth = auth
        let handle = auth.addStateDidChangeListener { _, user in changed(user?.uid) }
        return FirebaseFriendsSubscription { auth.removeStateDidChangeListener(handle) }
    }

    func call(name: String, payload: String, completed: @escaping (String?, FriendsTransportError?) -> Void) {
        call(name: name, payload: payload, publicRequest: name == "accountDeletionStatus", completed: completed)
    }

    private func call(name: String, payload: String, publicRequest: Bool, completed: @escaping (String?, FriendsTransportError?) -> Void) {
        guard enabled else { completed(nil, .failed); return }
        do {
            let data = try JSONSerialization.jsonObject(with: Data(payload.utf8))
            let functions: Functions
            if publicRequest {
                guard let app = deletionRequests else { completed(nil, .failed); return }
                functions = Functions.functions(app: app, region: FriendsConfiguration.shared.region)
            } else { functions = Functions.functions(region: FriendsConfiguration.shared.region) }
            functions.httpsCallable(name).call(data) { [weak self] result, error in
                if error != nil, name == "deleteAccount", !publicRequest, let self {
                    self.call(name: name, payload: payload, publicRequest: true, completed: completed)
                    return
                }
                guard error == nil, let result else { completed(nil, error?.friendsTransportError ?? .failed); return }
                do {
                    let json = try JSONSerialization.data(withJSONObject: result.data)
                    completed(String(decoding: json, as: UTF8.self), nil)
                } catch { completed(nil, .failed) }
            }
        } catch { completed(nil, .failed) }
    }

    func observeMemberships(owner: String, changed: @escaping (String?, FriendsTransportError?) -> Void) -> any FriendsSubscription {
        let registration = database.collection("friendships").document(owner).collection("friends").addSnapshotListener { snapshot, error in
            guard let snapshot, error == nil else { changed(nil, error?.friendsTransportError ?? .failed); return }
            do {
                let data = try JSONSerialization.data(withJSONObject: snapshot.documents.map { $0.data() })
                changed(String(decoding: data, as: UTF8.self), nil)
            } catch { changed(nil, .failed) }
        }
        return FirebaseFriendsSubscription { registration.remove() }
    }

    func observeIdentity(uid: String, changed: @escaping (String?, FriendsTransportError?) -> Void) -> any FriendsSubscription {
        observeDocument(
            database.collection("friendIdentities").document(uid),
            waitForServerIfMissing: uid == auth.currentUser?.uid,
            changed: changed)
    }

    func observeCategory(edition: String, uid: String, category: String, changed: @escaping (String?, FriendsTransportError?) -> Void) -> any FriendsSubscription {
        if category == "notes" {
            let registration = database.collection("users").document(uid).collection("profileEditions").document(edition).collection("records")
                .whereField("value.kind", isEqualTo: "note").addSnapshotListener { snapshot, error in
                    guard let snapshot, error == nil else { changed(nil, error?.friendsTransportError ?? .failed); return }
                    do { changed(String(decoding: try JSONSerialization.data(withJSONObject: snapshot.documents.map { $0.data() }), as: UTF8.self), nil) }
                    catch { changed(nil, .failed) }
                }
            return FirebaseFriendsSubscription { registration.remove() }
        }
        return observeDocument(database.collection("friendProfileEditions").document(edition).collection("profiles").document(uid).collection("categories").document(category), changed: changed)
    }

    private func observeDocument(
        _ document: DocumentReference,
        waitForServerIfMissing: Bool = false,
        changed: @escaping (String?, FriendsTransportError?) -> Void
    ) -> any FriendsSubscription {
        let registration = document.addSnapshotListener(includeMetadataChanges: waitForServerIfMissing) { snapshot, error in
            guard error == nil else { changed(nil, error?.friendsTransportError); return }
            if waitForServerIfMissing, let snapshot, snapshot.metadata.isFromCache, !snapshot.exists { return }
            guard let data = snapshot?.data() else { changed(nil, nil); return }
            do { changed(String(decoding: try JSONSerialization.data(withJSONObject: data), as: UTF8.self), nil) }
            catch { changed(nil, .failed) }
        }
        return FirebaseFriendsSubscription { registration.remove() }
    }

    func isEmailLink(value: String) -> Bool { enabled && auth.isSignIn(withEmailLink: value) }

    func sendEmail(email: String, completed: @escaping (FriendsTransportError?) -> Void) {
        let settings = ActionCodeSettings()
        settings.url = URL(string: FriendsConfiguration.shared.emailContinueURL)
        settings.handleCodeInApp = true
        settings.setIOSBundleID(FriendsConfiguration.shared.iosBundleID)
        settings.setAndroidPackageName(FriendsConfiguration.shared.androidPackage, installIfNotAvailable: false, minimumVersion: nil)
        settings.linkDomain = FriendsConfiguration.shared.authDomain
        auth.sendSignInLink(toEmail: email, actionCodeSettings: settings) { completed($0?.friendsTransportError) }
    }

    func finishEmail(email: String, link: String, completed: @escaping (FriendsTransportError?) -> Void) {
        auth.signIn(withEmail: email, link: link) { _, error in completed(error?.friendsTransportError) }
    }

    func signOut(completed: @escaping (FriendsTransportError?) -> Void) {
        do {
            try auth.signOut()
            GIDSignIn.sharedInstance.signOut()
            completed(nil)
        }
        catch { completed(error.friendsTransportError) }
    }

    @MainActor
    func signInWithGoogle(completed: @escaping (FriendsTransportError?) -> Void) {
        guard enabled, let clientID = FirebaseApp.app()?.options.clientID,
              !clientID.isEmpty else { completed(.authConfiguration); return }
        let scheme = clientID.split(separator: ".").reversed().joined(separator: ".")
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        guard urlTypes.contains(where: { ($0["CFBundleURLSchemes"] as? [String])?.contains(scheme) == true })
        else { completed(.authConfiguration); return }
        guard var presenter = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?.windows.first(where: \.isKeyWindow)?.rootViewController
        else { completed(.failed); return }
        while let presented = presenter.presentedViewController { presenter = presented }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
            if let error { completed(error.friendsTransportError); return }
            guard let user = result?.user, let token = user.idToken?.tokenString else { completed(.failed); return }
            let credential = GoogleAuthProvider.credential(withIDToken: token, accessToken: user.accessToken.tokenString)
            Auth.auth().signIn(with: credential) { _, error in completed(error?.friendsTransportError) }
        }
    }

    func signInWithApple(_ credential: ASAuthorizationAppleIDCredential, nonce: String, completed: @escaping (FriendsTransportError?) -> Void) {
        guard let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else { completed(.failed); return }
        let credential = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: credential.fullName)
        auth.signIn(with: credential) { _, error in completed(error?.friendsTransportError) }
    }
}

/// Reauthentication proves that the Apple grant belongs to this Firebase user.
@MainActor
private final class AppleAccountDeletionAuthorization: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let owner: String
    private var completed: ((FriendsTransportError?) -> Void)?
    private var nonce = ""
    init(owner: String, completed: @escaping (FriendsTransportError?) -> Void) { self.owner = owner; self.completed = completed }
    func start() {
        nonce = UUID().uuidString + UUID().uuidString
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
              let code = credential.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }),
              let user = Auth.auth().currentUser, user.uid == owner else { finish(.failed); return }
        let firebase = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: nil)
        user.reauthenticate(with: firebase) { [weak self] _, error in
            guard let self else { return }
            if let error { self.finish(error.friendsTransportError); return }
            guard Auth.auth().currentUser?.uid == self.owner else { self.finish(.cancelled); return }
            Auth.auth().revokeToken(withAuthorizationCode: code) { [weak self] error in self?.finish(error?.friendsTransportError) }
        }
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish((error as? ASAuthorizationError)?.code == .canceled ? .cancelled : .failed)
    }
    private func finish(_ error: FriendsTransportError?) { let callback = completed; completed = nil; callback?(error) }
}

extension Error {
    var friendsTransportError: FriendsTransportError {
        let error = self as NSError
        if error.domain == FirestoreErrorDomain, error.code == FirestoreErrorCode.permissionDenied.rawValue { return .permissionDenied }
        if error.domain == FunctionsErrorDomain {
            if (error.userInfo[FunctionsErrorDetailsKey] as? [String: Any])?["reason"] as? String == "key-auth-configuration" { return .authConfiguration }
            switch FunctionsErrorCode(rawValue: error.code) {
            case .resourceExhausted: return .rateLimited
            case .unauthenticated: return .unauthenticated
            case .failedPrecondition: return .conflict
            default: break
            }
        }
        if error.domain == kGIDSignInErrorDomain, error.code == GIDSignInError.canceled.rawValue { return .cancelled }
        if error.domain == AuthErrorDomain {
            switch AuthErrorCode(rawValue: error.code) {
            case .operationNotAllowed, .invalidClientID: return .authConfiguration
            case .accountExistsWithDifferentCredential, .credentialAlreadyInUse, .emailAlreadyInUse: return .accountConflict
            default: break
            }
        }
        return .failed
    }
}

extension FriendsError {
    var localizationKey: String {
        switch self {
        case .publish: "firebase.friends.publish_error"
        case .invalidLink: "firebase.friends.invalid_link"
        case .authentication: "firebase.friends.auth_error"
        case .authConfiguration: "firebase.friends.auth_configuration"
        case .accountConflict: "firebase.friends.account_conflict"
        default: "firebase.friends.error"
        }
    }
}

extension AccountKeyError {
    var localizationKey: String {
        switch self {
        case .invalidKey: "account.key.error.invalid"
        case .rateLimited: "account.key.error.rate"
        case .configuration: "account.key.error.configuration"
        case .conflict: "account.key.error.conflict"
        default: "account.key.error.connection"
        }
    }
}
#endif
