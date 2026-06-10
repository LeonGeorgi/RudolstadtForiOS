#if os(iOS)
import CloudKit
import SwiftUI

private enum ShareSheetPresentation: Identifiable {
    case inviteLink(URL)
    case manage(CKShare)

    var id: String {
        switch self {
        case .inviteLink(let url):
            return url.absoluteString
        case .manage(let share):
            return share.recordID.recordName
        }
    }
}

struct FriendsView: View {
    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var profileSync: FestivalProfileSyncStore

    @State private var shareSheetPresentation: ShareSheetPresentation?
    @State private var isShowingMyQRCode = false
    @State private var isShowingFriendScanner = false
    @State private var shareErrorMessage: String?
    @State private var badgeNameDraft = ""
    @State private var badgeColorHexDraft = FestivalProfileBadge.defaultColorHex
    @State private var isShowingBadgeColorPicker = false
    @FocusState private var isBadgeNameFieldFocused: Bool

    private let contentHorizontalPadding: CGFloat = 16
    private let recommendationTileSpacing: CGFloat = 12
    private let recommendationShelfVerticalPadding: CGFloat = 10
    private let recommendationTileWidthRatio = 0.6

    private var friendProfiles: [SharedFestivalProfile] {
        sortedFriendProfiles(profileSync.acceptedFriendProfiles)
    }

    private var followedByCount: Int {
        profileSync.acceptedShareParticipantCount
    }

    private var draftBadge: FestivalProfileBadge {
        .ownerBadge(
            rawName: badgeNameDraft,
            rawColorHex: badgeColorHexDraft
        )
    }

    private var friendRecommendations: [FriendArtistRecommendation] {
        friendArtistRecommendations(
            friendProfiles: friendProfiles,
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
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                profileBadgeSection
                togetherSections
                followingSection
                followedBySection
                privacySection
            }
            .padding(.horizontal, contentHorizontalPadding)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("more.friends.title")
        .sheet(item: $shareSheetPresentation, onDismiss: refreshShareParticipants) { presentation in
            switch presentation {
            case .inviteLink(let url):
                InviteLinkShareSheetView(url: url)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingFriendScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                }
                .disabled(isShareActionDisabled)
                .accessibilityLabel("friends.add_new")
            }
        }
        .onAppear {
            syncBadgeDraftsFromProfile()
            refreshShareParticipants()
        }
        .onChange(of: profile.badgeName) { _, _ in
            guard !isBadgeNameFieldFocused else {
                return
            }
            syncBadgeDraftsFromProfile()
        }
        .onChange(of: profile.badgeColorHex) { _, _ in
            guard !isBadgeNameFieldFocused else {
                return
            }
            syncBadgeDraftsFromProfile()
        }
    }

    private var profileBadgeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FriendsSectionTitle("friends.badge.section")

            profileBadgeEditor
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            Text("friends.badge.footer")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var profileBadgeEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                badgeColorMenu

                TextField("friends.badge.name.placeholder", text: $badgeNameDraft)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isBadgeNameFieldFocused)

                profileHeaderActionButtons
            }

            if !isSaveBadgeDisabled {
                HStack {
                    Spacer()
                    saveChangesButton
                }
            }
        }
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

    private var badgeColorMenu: some View {
        Button {
            isShowingBadgeColorPicker = true
        } label: {
            FestivalProfileBadgeAvatar(badge: draftBadge, diameter: 42)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingBadgeColorPicker) {
            BadgeColorPickerPopover(
                selectedColorHex: $badgeColorHexDraft,
                onSelect: {
                    isShowingBadgeColorPicker = false
                }
            )
            .presentationCompactAdaptation(.popover)
        }
    }

    private var profileHeaderActionButtons: some View {
        HStack(spacing: 8) {
            showQRCodeButton
            shareInviteLinkButton
        }
    }

    private var showQRCodeButton: some View {
        Button {
            isShowingMyQRCode = true
        } label: {
            Image(systemName: "qrcode")
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(isShareActionDisabled)
        .accessibilityLabel("friends.show_my_qr_code.accessibility")
    }

    private var shareInviteLinkButton: some View {
        Button {
            handleShareButtonTapped()
        } label: {
            Image(systemName: "square.and.arrow.up")
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(isShareActionDisabled)
        .accessibilityLabel("friends.share_invite_link.accessibility")
    }

    private var saveChangesButton: some View {
        Button("friends.badge.save") {
            profile.updateBadge(
                name: badgeNameDraft,
                colorHex: badgeColorHexDraft
            )
            syncBadgeDraftsFromProfile()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }

    @ViewBuilder
    private var togetherSections: some View {
        if friendProfiles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                FriendsSectionTitle("friends.together.section")

                Text("friends.together.no_friends")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
        } else {
            friendRecommendationsSection
        }
    }

    @ViewBuilder
    private var friendRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Label("friends.recommendations.title", systemImage: "sparkles")
                    .font(.headline)

                Spacer()

                if !friendRecommendations.isEmpty {
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

            if friendRecommendations.isEmpty {
                Text("friends.together.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: recommendationTileSpacing) {
                        ForEach(friendRecommendations) { recommendation in
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

    @ViewBuilder
    private var followingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FriendsSubsectionTitle("friends.following.section")

            if friendProfiles.isEmpty {
                friendsEmptyMessage("friends.following.empty")
            } else {
                ForEach(friendProfiles) { sharedProfile in
                    NavigationLink(
                        value: AppNavigationRoute.sharedFestivalProfile(profile: sharedProfile)
                    ) {
                        HStack(spacing: 8) {
                            FriendProfileListRow(
                                profile: sharedProfile,
                                subtitle: friendProfileSubtitle(sharedProfile)
                            )
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                isShowingFriendScanner = true
            } label: {
                Label("friends.add_new", systemImage: "qrcode.viewfinder")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isShareActionDisabled)

            Text("friends.following.add_hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var followedBySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FriendsSubsectionTitle("friends.followed_by.section")

            VStack(alignment: .leading, spacing: 10) {
                Text(followedByCountText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    handleManageShareButtonTapped()
                } label: {
                    HStack(spacing: 8) {
                        Label("friends.followed_by.details", systemImage: "person.2")
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isShareActionDisabled || profileSync.shareState != .shared)

                Divider()

                HStack(spacing: 8) {
                    followedByActionButton(
                        title: "friends.show_my_qr_code",
                        systemImage: "qrcode"
                    ) {
                        isShowingMyQRCode = true
                    }

                    followedByActionButton(
                        title: "friends.share_invite_link",
                        systemImage: "square.and.arrow.up"
                    ) {
                        handleShareButtonTapped()
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
    }

    private var followedByCountText: String {
        localizedCount(
            followedByCount,
            singularKey: "friends.followed_by.count.one",
            pluralKey: "friends.followed_by.count.other"
        )
    }

    private func followedByActionButton(
        title: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(
                    Color(.tertiarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(isShareActionDisabled)
    }

    private func friendsEmptyMessage(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FriendsSectionTitle("friends.privacy.section")

            Text("friends.privacy.body")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
        Task {
            await profile.refreshShareParticipants()
        }
    }

    private func handleShareButtonTapped() {
        Task {
            do {
                let inviteURL = try await profile.prepareOneTimeShareURL()
                shareSheetPresentation = .inviteLink(inviteURL)
            } catch {
                shareErrorMessage = error.localizedDescription
            }
        }
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

private struct FriendsSectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private struct FriendsSubsectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
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
