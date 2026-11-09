#if os(iOS)
    import AVFoundation
    import RudolstadtCore
    import SwiftUI
    import UIKit

    struct FirebaseFriendsView: View {
        private enum Destination: String, Hashable { case invitation, accept, recommendations, allFriends, accountKey }

        private struct ProfileEdit: Identifiable {
            let id: String
            let name: String
            let hue: Double
        }

        @ObservedObject var store: FirebaseFriendsStore
        @ObservedObject private var accountProfile: FestivalProfileStore
        @ObservedObject private var accountSync: FirebaseOwnProfileStore
        @ObservedObject private var sync: FirebaseOwnProfileStore
        @ObservedObject private var keys: KotlinStateStore<AccountKeyState>
        @ObservedObject private var deletion: KotlinStateStore<AccountDeletionState>
        @EnvironmentObject private var profile: FestivalProfileStore
        @EnvironmentObject private var friendProfiles: FriendProfilesStore
        @Environment(\.festivalData) private var festivalData
        @Environment(\.locale) private var locale
        @State private var destination: Destination?
        @State private var invitationOwner: String?
        @State private var scanning = false
        @State private var profileEdit: ProfileEdit?
        @State private var setupName = ""
        @State private var setupHue = FestivalProfileBadge.defaultHue
        @State private var choosingBadgeColor = false
        @State private var deletingAccount = false
        @State private var recommendationsWidth: CGFloat = 0

        init(accountProfile: FestivalProfileStore, sync: FirebaseOwnProfileStore) {
            let store = accountProfile.firebaseFriends
            self.store = store
            self.accountProfile = accountProfile
            self.accountSync = accountProfile.firebaseOwnProfile
            self.sync = sync
            self.keys = store.keys
            self.deletion = store.deletion
        }

        private var busy: Bool { store.state.busy || keys.state.busy || deletion.state.pending || deletion.state.busy }
        private var canSaveProfile: Bool {
            !busy && store.state.uid != nil && accountSync.state.uid == store.state.uid
        }
        private var badge: FestivalProfileBadge {
            FestivalProfileBadge(
                displayName: store.state.identity?.name ?? accountProfile.ownerBadge.displayName,
                hue: store.state.identity?.hue ?? accountProfile.badgeHue)
        }

        var body: some View {
            FirebaseAuthenticationGate(store: store, isFriendsTab: true) {
                Group {
                    if deletion.state.pending {
                        List { deletionFeedback }
                    } else if store.state.active {
                        if store.state.connections.isEmpty {
                            emptyFriends
                        } else {
                            friendsOverview
                        }
                    } else {
                        profileSetup
                    }
                }
                .id(store.state.uid)
                .navigationTitle(navigationTitle)
                .toolbar { friendsToolbar }
                .navigationDestination(item: $destination) { target in
                    switch target {
                    case .invitation: FirebaseFriendInvitationView(store: store)
                    case .accept: FirebaseFriendAcceptView(store: store)
                    case .recommendations: FriendsTogetherListView(kind: .recommendations)
                    case .allFriends: FirebaseAllFriendsList(store: store)
                    case .accountKey: FirebaseAccountKeyManagementView(store: store)
                    }
                }
                .navigationBarTitleDisplayMode(store.state.active ? .large : .inline)
                .onChange(of: store.state.uid) { _, _ in
                    destination = nil
                    scanning = false
                    presentInvitation()
                }
                .onChange(of: store.state.invitation?.token, initial: true) { _, _ in presentInvitation() }
                .onChange(of: store.state.active) { _, _ in presentInvitation() }
                .onChange(of: destination) { old, new in
                    if old == .accept, new == nil, store.state.active,
                        let invitationOwner, invitationOwner == store.state.uid
                    {
                        store.controller.dismissInvite()
                    }
                }
                .sheet(isPresented: $scanning) {
                    NavigationStack {
                        FirebaseFriendScanner { value in
                            scanning = false
                            if !store.controller.receive(value: value) { store.controller.invalidLink() }
                        }
                        .navigationTitle("friends.ui.scan")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("firebase.friends.dismiss") { scanning = false }
                            }
                        }
                    }
                }
                .sheet(item: $profileEdit) { edit in
                    FirebaseFriendProfileEditor(
                        name: edit.name, hue: edit.hue,
                        isSaveDisabled: !canSaveProfile || store.state.uid != edit.id
                    ) { name, hue in
                        guard canSaveProfile, store.state.uid == edit.id else { return }
                        profileEdit = nil
                        saveProfile(name: name, hue: hue)
                    }
                    .tint(.rudolstadt)
                }
                .alert("account.delete.title", isPresented: $deletingAccount) {
                    Button("account.delete.action", role: .destructive) { store.deleteAccount() }
                        .disabled(busy)
                    Button("account.cancel", role: .cancel) {}
                } message: {
                    let warning = Text("account.delete.warning")
                    store.requiresAppleDeletionAuthorization
                        ? Text("account.delete.warning.apple \(warning)")
                        : warning
                }
            }
            .onChange(of: store.state.uid) { _, _ in
                profileEdit = nil
                setupName = ""
                setupHue = FestivalProfileBadge.defaultHue
                choosingBadgeColor = false
                deletingAccount = false
            }
        }

        private var navigationTitle: LocalizedStringKey {
            if store.state.active || deletion.state.pending || !store.state.identityLoaded {
                return "firebase.friends.title"
            }
            return choosingBadgeColor ? "friends.ui.color" : "friends.ui.setup"
        }

        private var profileSetup: some View {
            let name = FestivalProfileBadge.normalizedName(setupName)
            return Form {
                if store.state.identityLoaded {
                    if choosingBadgeColor {
                        Section {
                            FirebaseFriendHueWheel(name: name ?? "", hue: $setupHue)
                                .frame(maxWidth: .infinity).padding(.vertical)
                        } footer: {
                            Text("friends.ui.color.hint")
                        }
                    } else {
                        Section {
                            FestivalProfileBadgeAvatar(
                                badge: FestivalProfileBadge(displayName: name ?? "", hue: FestivalProfileBadge.defaultHue),
                                diameter: 112
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical)
                            .accessibilityHidden(true)
                        }
                        .listRowBackground(Color.clear)
                        Section {
                            TextField("friends.ui.name", text: $setupName)
                                .textContentType(.nickname)
                                .onChange(of: setupName) { _, value in
                                    if value.count > 40 { setupName = String(value.prefix(40)) }
                                }
                        } header: {
                            Text("friends.ui.name.prompt")
                        }
                    }
                    Section {
                        Button("friends.badge.save") {
                            guard let name else { return }
                            if choosingBadgeColor {
                                saveProfile(name: name, hue: setupHue)
                            } else {
                                setupName = name
                                choosingBadgeColor = true
                            }
                        }
                        .disabled(busy || name == nil || (choosingBadgeColor && !canSaveProfile))
                        if choosingBadgeColor {
                            Button("account.back") { choosingBadgeColor = false }
                                .disabled(busy)
                        }
                    }
                }
                Section { profileMenu }
                deletionFeedback
                syncFeedback
                if let error = store.state.error {
                    Text(LocalizedStringKey(error.localizationKey)).foregroundStyle(.red)
                }
                if busy || (!store.state.identityLoaded && store.state.error == nil) {
                    ProgressView()
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }

        @ToolbarContentBuilder private var friendsToolbar: some ToolbarContent {
            if store.state.uid != nil && store.state.active && !deletion.state.pending {
                ToolbarItem(placement: .topBarTrailing) { addMenu }
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        sync.controller.retry()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(Text("profile.sync.now"))
                    .accessibilityIdentifier("profile-sync")
                    .disabled(busy || (sync.state.phase != .ready && sync.state.problem == nil))
                }
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                if #available(iOS 27.0, *) {
                    ToolbarItem(placement: .topBarTrailing) { profileMenu }
                        .contentMarginsRemoved()
                } else {
                    ToolbarItem(placement: .topBarTrailing) { profileMenu }
                }
            }
        }

        private var addMenu: some View {
            Menu {
                Button("firebase.friends.invite", systemImage: "qrcode", action: createInvitation)
                Button("friends.ui.scan", systemImage: "qrcode.viewfinder") { scanning = true }
            } label: { Image(systemName: "person.badge.plus") }
                .disabled(busy)
                .accessibilityLabel(Text("friends.ui.add"))
                .accessibilityIdentifier("friends-add")
        }

        private func createInvitation() {
            destination = .invitation
            store.controller.createInvite()
        }

        private var profileMenu: some View {
            Menu {
                if store.state.active {
                    Button("friends.badge.edit.title", systemImage: "pencil", action: editProfile)
                }
                if keys.state.isKeyAccount {
                    Button("account.key.title", systemImage: "key") { destination = .accountKey }
                }
                Section {
                    Button("firebase.friends.sign_out", systemImage: "rectangle.portrait.and.arrow.right") {
                        store.controller.signOut()
                    }
                    Button("account.delete.short", systemImage: "trash", role: .destructive) { deletingAccount = true }
                }
            } label: {
                if !store.state.active {
                    Text("account.title")
                } else if #available(iOS 27.0, *) {
                    FestivalProfileBadgeAvatar(badge: badge, diameter: 44)
                } else {
                    FestivalProfileBadgeAvatar(badge: badge, diameter: 32)
                }
            }
            .disabled(busy)
            .accessibilityLabel(Text(LocalizedStringKey(store.state.active ? "account.profile" : "account.title")))
            .accessibilityIdentifier("friends-profile")
        }

        private func editProfile() {
            guard let owner = store.state.uid, !busy else { return }
            profileEdit = ProfileEdit(id: owner, name: store.state.identity?.name ?? accountProfile.badgeName, hue: badge.hue)
        }

        private func saveProfile(name: String, hue: Double) {
            guard canSaveProfile, let uid = store.state.uid,
                store.controller.current.uid == uid, accountSync.controller.current.uid == uid
            else { return }
            let selected = ProfileReducer.shared.apply(
                profile: accountProfile.state.profile, mutation: .updateBadge(name: name, hue: hue))
            accountProfile.updateBadge(name: name, hue: hue)
            store.controller.activate(profile: selected)
        }

        @ViewBuilder private var syncFeedback: some View {
            if let problem = sync.state.problem {
                Section {
                    Text(LocalizedStringKey(problem.localizationKey)).foregroundStyle(.red)
                    if !store.state.active {
                        Button("profile.sync.retry") { sync.controller.retry() }.disabled(busy)
                    }
                }
            }
        }

        @ViewBuilder private var deletionFeedback: some View {
            if let problem = deletion.state.problem {
                let key = switch problem {
                case .localStorage: "account.delete.error.local"
                case .authentication: "account.delete.error.auth"
                default: "account.delete.error.connection"
                }
                Section { Text(LocalizedStringKey(key)).foregroundStyle(.red) }
            }
            if deletion.state.pending {
                Section {
                    Text("account.delete.pending")
                    Button("account.delete.retry") { store.retryDeletion() }.disabled(deletion.state.busy)
                }
            }
            if deletion.state.busy { Section { ProgressView() } }
        }

        @ViewBuilder private var friendsFeedback: some View {
            deletionFeedback
            syncFeedback
            FirebaseFriendsConnectionFeedback(store: store, isBusy: busy)
        }

        private var emptyFriends: some View {
            ScrollView {
                VStack(spacing: 12) {
                    friendsFeedback
                    ContentUnavailableView {
                        Label("friends.ui.empty", systemImage: "person.2")
                    } description: {
                        Text("friends.ui.empty.description")
                            .frame(maxWidth: 280)
                    } actions: {
                        VStack(spacing: 8) {
                            Button("firebase.friends.invite", action: createInvitation)
                                .buttonStyle(.borderedProminent)
                            Button("friends.ui.scan") { scanning = true }
                                .buttonStyle(.borderless)
                        }
                        .controlSize(.large)
                        .disabled(busy)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(16)
            }
            .defaultScrollAnchor(.center, for: .alignment)
            .background(Color(uiColor: .systemGroupedBackground))
            .tint(.rudolstadt)
        }

        private var friendsOverview: some View {
            List {
                friendsFeedback
                Section {
                    let recommendations = FriendRecommendationContext(
                        artists: festivalData.artists, events: festivalData.events, locale: locale
                    )
                    .recommendations(
                        friendProfiles: friendProfiles.state.profiles, savedEventIDs: profile.savedEvents, ratings: profile.ratings)

                    Button {
                        destination = .recommendations
                    } label: {
                        FriendSectionLinkLabel(title: Text("friends.recommendations.title"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("friends-recommendations")
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    if recommendations.isEmpty {
                        Text("friends.ui.recommendations.empty").foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    } else {
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 12) {
                                ForEach(recommendations.prefix(12)) { recommendation in
                                    NavigationLink(
                                        value: AppNavigationRoute.artist(
                                            id: recommendation.id,
                                            highlightedEventId: recommendation.highlightedEventID,
                                            transitionSourceID: nil)
                                    ) {
                                        FriendArtistRecommendationTile(recommendation: recommendation).frame(width: 240)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("friend-recommendation-\(recommendation.id)")
                                }
                            }
                            .scrollTargetLayout()
                            .padding(.trailing, max(0, recommendationsWidth - 240 - 40))
                            .padding(.bottom, 22)
                        }
                        .contentMargins(.horizontal, 20, for: .scrollContent)
                        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { recommendationsWidth = $0 }
                        .scrollIndicators(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .friendsShelfMargins()
                Section {
                    Button {
                        destination = .allFriends
                    } label: {
                        FriendSectionLinkLabel(
                            title: Text("firebase.friends.title"), count: store.state.connections.count
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("friends.ui.all"))
                    .accessibilityValue(Text(store.state.connections.count, format: .number))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("friends-all")
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 8) {
                            ForEach(store.state.connections, id: \.uid) { friend in
                                NavigationLink(value: AppNavigationRoute.firebaseFriend(uid: friend.uid)) {
                                    FirebaseFriendTile(connection: friend)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, 16, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
                    .scrollIndicators(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .friendsShelfMargins()
            }
            .listStyle(.insetGrouped)
        }

        private func presentInvitation() {
            if store.state.active, store.state.invitation != nil {
                invitationOwner = store.state.uid
                destination = .accept
            } else if destination == .accept, store.state.invitation == nil {
                destination = nil
            }
        }
    }

    private struct FirebaseFriendTile: View {
        let connection: FriendConnection
        @ScaledMetric(relativeTo: .subheadline) private var nameWidth: CGFloat = 94

        var body: some View {
            VStack(spacing: 7) {
                FestivalProfileBadgeAvatar(
                    badge: FestivalProfileBadge(displayName: connection.name ?? "?", hue: connection.hue), diameter: 82
                )
                .accessibilityHidden(true)
                Text(connection.name ?? friendsLocalizedString("friends.global.loading"))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: max(94, nameWidth))
            .contentShape(Rectangle())
        }
    }

    private struct FirebaseAllFriendsList: View {
        @ObservedObject var store: FirebaseFriendsStore
        @State private var removing: FriendConnection?

        var body: some View {
            List {
                FirebaseFriendsConnectionFeedback(store: store, isBusy: store.state.busy)
                if store.state.connections.isEmpty {
                    Text("friends.ui.empty").foregroundStyle(.secondary)
                } else {
                    Section {
                        ForEach(store.state.connections, id: \.uid) { friend in
                            NavigationLink(value: AppNavigationRoute.firebaseFriend(uid: friend.uid)) {
                                FirebaseFriendRow(connection: friend)
                            }
                            .swipeActions { removeButton(for: friend) }
                            .contextMenu { removeButton(for: friend) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("friends.ui.all")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: store.state.uid) { _, _ in removing = nil }
            .confirmationDialog(
                "firebase.friends.remove",
                isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })
            ) {
                if let friend = removing {
                    Button("firebase.friends.remove", role: .destructive) {
                        store.controller.removeFriend(uid: friend.uid)
                        removing = nil
                    }
                }
            } message: {
                Text("firebase.friends.remove_consent")
            }
        }

        private func removeButton(for friend: FriendConnection) -> some View {
            Button("firebase.friends.remove", role: .destructive) { removing = friend }
                .disabled(store.state.busy)
        }
    }

    private struct FirebaseFriendsConnectionFeedback: View {
        @ObservedObject var store: FirebaseFriendsStore
        let isBusy: Bool

        var body: some View {
            if let error = store.state.error?.localizationKey {
                Section {
                    Text(LocalizedStringKey(error)).foregroundStyle(.red)
                    Button("firebase.friends.retry") { store.controller.retryPublish() }.disabled(isBusy)
                }
            }
            if store.state.busy { ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear) }
        }
    }

    private struct FirebaseFriendRow: View {
        let connection: FriendConnection

        var body: some View {
            HStack(spacing: 12) {
                FestivalProfileBadgeAvatar(
                    badge: FestivalProfileBadge(displayName: connection.name ?? "?", hue: connection.hue), diameter: 32
                )
                .accessibilityHidden(true)
                Text(connection.name ?? friendsLocalizedString("friends.global.loading"))
                    .font(.body)
                    .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            }
        }
    }

    struct FirebaseFriendProfileEditor: View {
        private let initialName: String
        private let initialHue: Double
        let isSaveDisabled: Bool
        let onSave: (String, Double) -> Void

        @State private var name: String
        @State private var hue: Double
        @Environment(\.dismiss) private var dismiss

        init(name: String, hue: Double, isSaveDisabled: Bool, onSave: @escaping (String, Double) -> Void) {
            initialName = name
            initialHue = hue
            self.isSaveDisabled = isSaveDisabled
            self.onSave = onSave
            _name = State(initialValue: name)
            _hue = State(initialValue: hue)
        }

        private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

        private var canSave: Bool {
            !isSaveDisabled && !cleanName.isEmpty && (cleanName != initialName || hue != initialHue)
        }

        private var confirmationRole: ButtonRole? {
            if #available(iOS 26.0, *) { .confirm } else { nil }
        }

        var body: some View {
            NavigationStack {
                Form {
                    Section {
                        TextField("friends.ui.name", text: $name)
                            .textContentType(.nickname)
                            .onChange(of: name) { _, value in
                                if value.count > 40 { name = String(value.prefix(40)) }
                            }
                    }
                    Section {
                        FirebaseFriendHueWheel(name: cleanName, hue: $hue)
                            .frame(maxWidth: .infinity).padding(.vertical)
                    } header: {
                        Text("friends.ui.color")
                    } footer: {
                        Text("friends.ui.color.hint")
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("friends.badge.edit.title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) { dismiss() } label: { Image(systemName: "xmark") }
                            .accessibilityLabel(Text("account.cancel"))
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: confirmationRole) { onSave(cleanName, hue) } label: { Image(systemName: "checkmark") }
                            .accessibilityLabel(Text("friends.badge.save"))
                            .disabled(!canSave)
                    }
                }
            }
        }
    }

    private struct FirebaseFriendHueWheel: View {
        let name: String
        @Binding var hue: Double
        private let diameter: CGFloat = 232
        private static let colors = stride(from: 0.0, through: 360.0, by: 6.0).map { color(for: $0) }

        private static func color(for hue: Double) -> Color {
            let rgb = ProfileColors.shared.rgb(hue: hue)
            return Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1)
        }

        var body: some View {
            let angle = Angle.degrees(hue - 90)
            let radius = diameter / 2 - 18
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(colors: Self.colors, center: .center,
                            startAngle: .degrees(-90), endAngle: .degrees(270)), lineWidth: 20)
                    .padding(18)
                FestivalProfileBadgeAvatar(
                    badge: FestivalProfileBadge(displayName: name, hue: hue), diameter: 112)
                Circle()
                    .fill(Self.color(for: hue))
                    .overlay { Circle().strokeBorder(.white, lineWidth: 3) }
                    .frame(width: 28, height: 28)
                    .offset(x: CGFloat(cos(angle.radians)) * radius, y: CGFloat(sin(angle.radians)) * radius)
            }
            .frame(width: diameter, height: diameter)
            .contentShape(HueRingHitArea(), eoFill: true)
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                if let selected = ProfileColors.shared.hueForDrag(
                    x: Double(value.location.x), y: Double(value.location.y), diameter: Double(diameter))
                {
                    hue = selected.doubleValue
                }
            })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("friends.ui.hue"))
            .accessibilityValue("\(Int(hue.rounded()))°")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: hue = (hue + 5).truncatingRemainder(dividingBy: 360)
                case .decrement: hue = (hue + 355).truncatingRemainder(dividingBy: 360)
                @unknown default: break
                }
            }
            .accessibilityIdentifier("friends-hue-wheel")
        }

        private struct HueRingHitArea: Shape {
            func path(in rect: CGRect) -> Path {
                var path = Path(ellipseIn: rect)
                path.addEllipse(in: rect.insetBy(dx: rect.width * 0.2, dy: rect.height * 0.2))
                return path
            }
        }
    }

    private struct FirebaseFriendInvitationView: View {
        @ObservedObject var store: FirebaseFriendsStore
        var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    Text("friends.ui.invite.hint").frame(maxWidth: .infinity, alignment: .leading)
                    if store.state.busy {
                        ProgressView().frame(height: 280)
                    } else if let url = store.invitationURL {
                        QRCodeImageCard(url: url)
                        Text("firebase.friends.invite_lifetime").font(.footnote).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ShareLink(item: url) { Text("firebase.friends.share").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                    }
                    if let error = store.state.error?.localizationKey {
                        Text(LocalizedStringKey(error)).foregroundStyle(.red)
                    }
                    Button { store.controller.createInvite() } label: {
                        Text("friends.ui.new.invite")
                    }
                    .disabled(store.state.busy)
                }.padding(24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("friends.ui.invitation").navigationBarTitleDisplayMode(.inline)
        }
    }

    private struct FirebaseFriendAcceptView: View {
        @ObservedObject var store: FirebaseFriendsStore
        var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    if let name = store.state.previewName {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 64)).foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(name).font(.title2.weight(.semibold))
                        Text(String(format: friendsLocalizedString("friends.ui.invited.by"), name))
                        Text("firebase.friends.consent").font(.footnote).foregroundStyle(.secondary)
                        Button("friends.ui.accept") { store.controller.acceptInvite() }
                            .buttonStyle(.borderedProminent).controlSize(.large).disabled(store.state.busy)
                    }
                    if store.state.busy { ProgressView() }
                    if let error = store.state.error?.localizationKey {
                        Text(LocalizedStringKey(error)).foregroundStyle(.red)
                        Button("firebase.friends.preview") { store.controller.previewInvite() }.disabled(
                            store.state.busy)
                    }
                    Button("firebase.friends.dismiss") { store.controller.dismissInvite() }.disabled(store.state.busy)
                }.frame(maxWidth: .infinity).padding(24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("friends.ui.invitation").navigationBarTitleDisplayMode(.inline)
            .task(id: "\(store.state.invitation?.token ?? "")-\(store.state.busy)") {
                if store.state.invitation != nil, store.state.active, !store.state.busy,
                    store.state.previewName == nil, store.state.error == nil
                {
                    store.controller.previewInvite()
                }
            }
        }
    }

    struct LiveFirebaseFriendDetail: View {
        @EnvironmentObject private var friends: FriendProfilesStore
        let uid: String
        let section: FriendProfileSection?
        var body: some View {
            if let profile = friends.state.profiles.first(where: { $0.id == uid }) {
                SharedFestivalProfileDetailView(profile: profile, section: section, friendUID: uid)
            } else {
                ContentUnavailableView("friends.global.no_data", systemImage: "person.crop.circle")
            }
        }
    }

    struct FirebaseFriendScanner: View {
        let scanned: (String) -> Void
        @State private var authorized = false
        @State private var checked = false
        @State private var failure: String?
        @Environment(\.openURL) private var openURL
        @Environment(\.scenePhase) private var scenePhase

        var body: some View {
            Group {
                if authorized, failure == nil {
                    VStack(spacing: 24) {
                        Text("friends.ui.scan.hint")
                        QRCodeScannerView(onCodeDetected: scanned, onFailure: { failure = $0 })
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    }.padding(20)
                } else if checked || failure != nil {
                    ContentUnavailableView {
                        Label("friends.ui.camera", systemImage: "camera")
                    } description: {
                        Text(failure ?? friendsLocalizedString("friends.ui.camera.hint"))
                    } actions: {
                        Button("friends.ui.settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }.buttonStyle(.borderedProminent)
                    }
                } else {
                    ProgressView()
                }
            }
            .task {
                authorized = await AVCaptureDevice.requestAccess(for: .video)
                checked = true
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { authorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized }
            }
        }
    }
    private extension View {
        @ViewBuilder func friendsShelfMargins() -> some View {
            if #available(iOS 26.0, *) { self.listSectionMargins(.horizontal, 0) }
            else { self }
        }
    }
#endif
