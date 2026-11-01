#if os(iOS)
import CloudKit
import SwiftUI

private enum ShareSheetPresentation: Identifiable {
    case inviteLink
    case manage(CKShare)

    var id: String {
        switch self {
        case .inviteLink:
            return "inviteLink"
        case .manage(let share):
            return share.recordID.recordName
        }
    }
}

struct FriendsView: View {
    @Environment(\.festivalEdition) private var edition
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var friends: FriendProfilesStore
    @EnvironmentObject private var profileSync: FestivalProfileSyncStore

    @State private var shareSheetPresentation: ShareSheetPresentation?
    @State private var isShowingMyQRCode = false
    @State private var isShowingFriendScanner = false
    @State private var isShowingProfileEditor = false
    @State private var shareErrorMessage: String?
    @State private var badgeNameDraft = ""
    @State private var badgeColorHexDraft = FestivalProfileBadge.defaultColorHex
    @State private var isCheckingICloud = false
    @FocusState private var isBadgeNameFieldFocused: Bool

    private var friendProfiles: [SharedFestivalProfile] {
        sortedFriendProfiles(friends.profiles)
    }

    private var followedByCount: Int {
        profileSync.acceptedShareParticipantCount
    }

    private var isBadgeConfigured: Bool {
        FestivalProfileBadge.normalizedName(profile.badgeName) != nil
    }

    private var isICloudAvailable: Bool {
        guard case .available = profileSync.iCloudStatus else {
            return false
        }
        return true
    }

    private var isSetupComplete: Bool {
        isBadgeConfigured && isICloudAvailable
    }

    var body: some View {
        List {
            if edition.isExperimental {
                Text("festival.experimental.sharing_unavailable")
                    .foregroundStyle(.secondary)
            } else if profile.isReadOnly {
                Text("archive.personal_data_unavailable")
                    .foregroundStyle(.secondary)
            } else if !isSetupComplete {
                Section {
                    setupIntroduction
                        .listRowBackground(Color.clear)
                }
                profileBadgeSection
                iCloudSetupSection
            } else {
                Section {
                    profileSummary
                } footer: {
                    Text("friends.privacy.summary")
                }
                togetherSections
                followingSection
                followedBySection
            }
        }
        .font(.body)
        .listStyle(.insetGrouped)
        .navigationTitle("more.friends.title")
        .toolbar {
            if edition.usesLiveServices && isSetupComplete {
                ToolbarItem(placement: .topBarTrailing) {
                    connectionMenu
                }
            }
        }
        .sheet(item: $shareSheetPresentation, onDismiss: refreshShareParticipants) { presentation in
            switch presentation {
            case .inviteLink:
                InviteLinkShareSheetView(profile: profile)
            case .manage(let share):
                CloudSharingControllerView(share: share)
            }
        }
        .sheet(isPresented: $isShowingMyQRCode) {
            MyProfileQRCodeSheetView(profile: profile)
        }
        .sheet(isPresented: $isShowingFriendScanner) {
            FriendProfileQRScannerSheetView(profile: profile)
        }
        .sheet(isPresented: $isShowingProfileEditor, onDismiss: syncBadgeDraftsFromProfile) {
            ProfileBadgeEditorSheet(profile: profile)
        }
        .alert("friends.share_unavailable.title", isPresented: Binding(
            get: { shareErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    shareErrorMessage = nil
                }
            }
        )) {
            Button("friends.alert.ok", role: .cancel) {
                shareErrorMessage = nil
            }
        } message: {
            Text(shareErrorMessage ?? "")
        }
        .onAppear {
            syncBadgeDraftsFromProfile()
            refreshShareParticipants()
        }
        .onChange(of: profile.badgeName) { _, _ in
            guard !isShowingProfileEditor, !isBadgeNameFieldFocused else {
                return
            }
            syncBadgeDraftsFromProfile()
        }
        .onChange(of: profile.badgeColorHex) { _, _ in
            guard !isShowingProfileEditor, !isBadgeNameFieldFocused else {
                return
            }
            syncBadgeDraftsFromProfile()
        }
    }

    private var setupIntroduction: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("friends.setup.title")
                .font(.title3.weight(.semibold))

            Text(setupNextStepKey)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var setupNextStepKey: LocalizedStringKey {
        if !isBadgeConfigured {
            return "friends.setup.next.badge"
        }
        if isCheckingICloud || profileSync.iCloudStatus == .checking {
            return "friends.setup.next.icloud_checking"
        }
        return "friends.setup.next.icloud_unavailable"
    }

    private var profileBadgeSection: some View {
        Section {
            profileBadgeEditor
            if isBadgeConfigured {
                Label("friends.setup.badge.ready", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
            }
        } header: {
            Text("friends.setup.badge.section")
        } footer: {
            Text("friends.badge.footer")
        }
    }

    private var profileSummary: some View {
        Button {
            syncBadgeDraftsFromProfile()
            isShowingProfileEditor = true
        } label: {
            HStack(spacing: 12) {
                FestivalProfileBadgeAvatar(badge: profile.ownerBadge, diameter: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.ownerBadge.displayName)
                        .font(.headline)
                    Text("friends.badge.section")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("friends.badge.edit")
                    .foregroundStyle(.tint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var profileBadgeEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            badgeFields
            if !isSaveBadgeDisabled {
                HStack {
                    Spacer()
                    saveChangesButton
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
    }

    private var badgeFields: some View {
        ProfileBadgeFields(
            name: $badgeNameDraft,
            colorHex: $badgeColorHexDraft,
            isNameFocused: $isBadgeNameFieldFocused
        )
    }

    private var isShareActionDisabled: Bool {
        if profileSync.isPreparingShare {
            return true
        }
        guard case .available = profileSync.iCloudStatus else {
            return true
        }
        return false
    }

    private var isSaveBadgeDisabled: Bool {
        let normalizedName = FestivalProfileBadge.normalizedName(badgeNameDraft)
        guard let normalizedName else {
            return true
        }
        return normalizedName == profile.badgeName
            && FestivalProfileBadge.resolvedColorHex(badgeColorHexDraft) == profile.badgeColorHex
    }

    private var saveChangesButton: some View {
        Button("friends.badge.save") {
            profile.updateBadge(
                name: badgeNameDraft,
                colorHex: badgeColorHexDraft
            )
            isBadgeNameFieldFocused = false
            isShowingProfileEditor = false
            syncBadgeDraftsFromProfile()
        }
    }

    private var iCloudSetupSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                iCloudStatusIcon
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(iCloudStatusTitleKey)
                        .font(.subheadline.weight(.semibold))

                    if let detail = iCloudStatusDetail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if shouldOfferICloudRetry {
                        Button("friends.setup.icloud.retry") {
                            checkICloudAgain()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                }

                Spacer(minLength: 0)
            }
        } header: {
            Text("friends.setup.icloud.section")
        }
    }

    @ViewBuilder
    private var iCloudStatusIcon: some View {
        if isCheckingICloud || profileSync.iCloudStatus == .checking {
            ProgressView()
        } else if isICloudAvailable {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    private var iCloudStatusTitleKey: LocalizedStringKey {
        if isCheckingICloud || profileSync.iCloudStatus == .checking {
            return "friends.setup.icloud.checking"
        }
        if isICloudAvailable {
            return "friends.setup.icloud.ready"
        }
        return "friends.setup.icloud.unavailable"
    }

    private var iCloudStatusDetail: String? {
        guard case .unavailable(let reason) = profileSync.iCloudStatus else {
            return nil
        }
        return localizedICloudUnavailableReason(reason)
    }

    private var shouldOfferICloudRetry: Bool {
        guard !isCheckingICloud, case .unavailable = profileSync.iCloudStatus else {
            return false
        }
        return true
    }

    private var connectionMenu: some View {
        Menu {
            Button {
                isShowingFriendScanner = true
            } label: {
                Label("friends.scan_qr", systemImage: "qrcode.viewfinder")
            }
            Button {
                isShowingMyQRCode = true
            } label: {
                Label("friends.show_my_qr_code", systemImage: "qrcode")
            }
            Button {
                shareSheetPresentation = .inviteLink
            } label: {
                Label("friends.share_invite_link", systemImage: "square.and.arrow.up")
            }
        } label: {
            Label("friends.add_new", systemImage: "plus")
        }
        .disabled(isShareActionDisabled)
    }

    @ViewBuilder
    private var togetherSections: some View {
        if !friendProfiles.isEmpty {
            Section {
                FriendsRecommendationsSection()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .navigationLinkIndicatorVisibility(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
    }

    @ViewBuilder
    private var followingSection: some View {
        Section {
            if friendProfiles.isEmpty {
                friendsEmptyMessage("friends.following.empty")
            } else {
                ForEach(friendProfiles) { sharedProfile in
                    NavigationLink(
                        value: AppNavigationRoute.sharedFestivalProfile(profile: sharedProfile)
                    ) {
                        FriendProfileListRow(
                            profile: sharedProfile,
                            subtitle: friendProfileSubtitle(sharedProfile)
                        )
                    }
                }
            }
        } header: {
            Text("friends.following.section")
        } footer: {
            if friendProfiles.isEmpty {
                Text("friends.together.no_friends")
            }
        }
    }

    @ViewBuilder
    private var followedBySection: some View {
        Section {
            Text(followedByCountText)
                .foregroundStyle(.secondary)
            if profileSync.shareState == .shared {
                Button {
                    handleManageShareButtonTapped()
                } label: {
                    Label("friends.followed_by.details", systemImage: "person.2")
                }
                .disabled(profileSync.isPreparingShare)
            }
        } header: {
            Text("friends.followed_by.section")
        }
    }

    private var followedByCountText: String {
        localizedCount(
            followedByCount,
            singularKey: "friends.followed_by.count.one",
            pluralKey: "friends.followed_by.count.other"
        )
    }

    private func friendsEmptyMessage(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func friendProfileSubtitle(_ profile: SharedFestivalProfile) -> String {
        let artistCount = profile.artistPreferences.count
        let eventCount = profile.savedEventIDs.count
        let savedEvents = localizedCount(
            eventCount,
            singularKey: "friends.count.saved_event.one",
            pluralKey: "friends.count.saved_event.other"
        )
        let ratedArtists = localizedCount(
            artistCount,
            singularKey: "friends.count.rated_artist.one",
            pluralKey: "friends.count.rated_artist.other"
        )
        return String(
            format: friendsLocalizedString("friends.profile.subtitle.format"),
            savedEvents,
            ratedArtists
        )
    }

    private func localizedCount(
        _ count: Int,
        singularKey: String,
        pluralKey: String
    ) -> String {
        let key = count == 1 ? singularKey : pluralKey
        return String.localizedStringWithFormat(
            friendsLocalizedString(key),
            Int64(count)
        )
    }

    private func syncBadgeDraftsFromProfile() {
        badgeNameDraft = profile.badgeName
        badgeColorHexDraft = profile.badgeColorHex
    }

    private func refreshShareParticipants() {
        guard edition.usesLiveServices, !profile.isReadOnly else { return }
        Task {
            await profile.refreshShareParticipants()
        }
    }

    private func checkICloudAgain() {
        isCheckingICloud = true
        Task {
            await profile.refreshFromCloud(reason: "friends-setup")
            isCheckingICloud = false
        }
    }

    private func localizedICloudUnavailableReason(_ reason: String) -> String {
        let localizationKey: String
        switch reason {
        case "Could not determine your iCloud status.":
            localizationKey = "friends.setup.icloud.reason.unknown"
        case "Sign in to iCloud to sync your festival profile.":
            localizationKey = "friends.setup.icloud.reason.no_account"
        case "iCloud sync is restricted on this device.":
            localizationKey = "friends.setup.icloud.reason.restricted"
        case "iCloud is temporarily unavailable.":
            localizationKey = "friends.setup.icloud.reason.temporary"
        case "iCloud is unavailable right now.":
            localizationKey = "friends.setup.icloud.reason.unavailable"
        case "Cloud sync disabled":
            localizationKey = "friends.setup.icloud.reason.disabled"
        default:
            return reason
        }
        return friendsLocalizedString(localizationKey)
    }

    private func handleManageShareButtonTapped() {
        if let cachedShare = profile.cachedShare() {
            shareSheetPresentation = .manage(cachedShare)
            return
        }

        Task {
            await loadShareManagementSheet()
        }
    }

    private func loadShareManagementSheet() async {
        do {
            let share = try await profile.prepareShare()
            shareSheetPresentation = .manage(share)
        } catch {
            shareErrorMessage = error.localizedDescription
        }
    }

}

private struct FriendsRecommendationsSection: View {
    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var friends: FriendProfilesStore

    private let contentHorizontalPadding: CGFloat = 16
    private let recommendationTileSpacing: CGFloat = 12
    private let recommendationShelfVerticalPadding: CGFloat = 10
    private let recommendationTileWidthRatio = 0.6

    private var friendRecommendations: [FriendArtistRecommendation] {
        friendArtistRecommendations(
            friendProfiles: sortedFriendProfiles(friends.profiles),
            artists: festivalData.artists,
            events: festivalData.events,
            excludedArtistIDs: friendRecommendationExcludedArtistIDs(
                savedEventIDs: profile.savedEvents,
                ratings: profile.ratings,
                events: festivalData.events
            )
        )
    }

    var body: some View {
        let recommendations = friendRecommendations

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Label("friends.recommendations.title", systemImage: "sparkles")
                    .font(.headline)

                Spacer()

                if !recommendations.isEmpty {
                    NavigationLink(
                        value: AppNavigationRoute.friendsTogether(kind: .recommendations)
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(
                                Color(.secondarySystemGroupedBackground),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("friends.recommendations.more")
                }
            }

            if recommendations.isEmpty {
                Text("friends.together.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: recommendationTileSpacing) {
                        ForEach(recommendations) { recommendation in
                            NavigationLink(
                                value: AppNavigationRoute.artist(
                                    id: recommendation.artist.id,
                                    highlightedEventId: recommendation.highlightedEventID,
                                    transitionSourceID: nil
                                )
                            ) {
                                FriendArtistRecommendationTile(recommendation: recommendation)
                                    .containerRelativeFrame(.horizontal) { length, _ in
                                        length * recommendationTileWidthRatio
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, recommendationShelfVerticalPadding)
                    .scrollTargetLayout()
                }
                .contentMargins(
                    .horizontal,
                    contentHorizontalPadding,
                    for: .scrollContent
                )
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
                .padding(.horizontal, -contentHorizontalPadding)
            }
        }
    }
}

private struct ProfileBadgeEditorSheet: View {
    @ObservedObject var profile: FestivalProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var colorHex: String
    @FocusState private var isNameFocused: Bool

    init(profile: FestivalProfileStore) {
        self.profile = profile
        _name = State(initialValue: profile.badgeName)
        _colorHex = State(initialValue: profile.badgeColorHex)
    }

    private var isSaveDisabled: Bool {
        guard let normalizedName = FestivalProfileBadge.normalizedName(name) else {
            return true
        }
        return normalizedName == profile.badgeName
            && FestivalProfileBadge.resolvedColorHex(colorHex) == profile.badgeColorHex
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ProfileBadgeFields(
                        name: $name,
                        colorHex: $colorHex,
                        isNameFocused: $isNameFocused
                    )
                } footer: {
                    Text("friends.badge.footer")
                }
            }
            .navigationTitle("friends.badge.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("friends.cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("friends.badge.save") {
                        profile.updateBadge(name: name, colorHex: colorHex)
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }
}

private struct ProfileBadgeFields: View {
    @Binding var name: String
    @Binding var colorHex: String
    var isNameFocused: FocusState<Bool>.Binding
    @State private var isShowingColorPicker = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                isShowingColorPicker = true
            } label: {
                FestivalProfileBadgeAvatar(
                    badge: .ownerBadge(rawName: name, rawColorHex: colorHex),
                    diameter: 42
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isShowingColorPicker) {
                BadgeColorPickerPopover(selectedColorHex: $colorHex) {
                    isShowingColorPicker = false
                }
                .presentationCompactAdaptation(.popover)
            }
            TextField("friends.badge.name.placeholder", text: $name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused(isNameFocused)
        }
    }
}

private struct BadgeColorPickerPopover: View {
    @Binding var selectedColorHex: String
    let onSelect: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 44), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(FestivalProfileBadge.paletteColorHexes, id: \.self) { colorHex in
                BadgeColorSwatchButton(
                    colorHex: colorHex,
                    isSelected: selectedColorHex == colorHex
                ) {
                    selectedColorHex = colorHex
                    onSelect()
                }
            }
        }
        .padding(16)
        .frame(width: 224)
    }
}

private struct BadgeColorSwatchButton: View {
    let colorHex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let color = Color(festivalProfileHex: colorHex) ?? .rudolstadt
        let checkmarkColor = color.prefersDarkForeground
            ? Color.black.opacity(0.78)
            : Color.white

        Button(action: action) {
            Circle()
                .fill(color.gradient)
                .frame(width: 34, height: 34)
                .overlay {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.primary.opacity(0.6) : Color.primary.opacity(0.16),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(checkmarkColor)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(colorHex))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
struct FriendsView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        NavigationStack {
            FriendsView()
                .navigationDestination(for: AppNavigationRoute.self) { _ in
                    EmptyView()
                }
        }
        .previewMockEnvironment(suiteName: "FriendsViewPreview")
    }
}
#endif
#endif
