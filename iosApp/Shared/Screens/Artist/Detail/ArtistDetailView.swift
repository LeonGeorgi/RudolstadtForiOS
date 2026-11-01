import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ArtistDetailView: View {
    @EnvironmentObject private var dataStore: DataStore
    private enum Layout {
        static let maximumContentWidth: CGFloat = 720
        static let minimumImageColumnWidth: CGFloat = 220
        static let maximumImageColumnWidth: CGFloat = 320
        static let compactHorizontalMargin: CGFloat = 16
        static let regularHorizontalMargin: CGFloat = 24
        static let edgeToEdgeIntroTopSpacing: CGFloat = 12
    }

    private struct PresentedBrowserURL: Identifiable {
        let id = UUID()
        let url: URL
    }

    let artist: Artist
    let highlightedEventId: Int?
    let navigate: ((AppNavigationRoute) -> Void)?

    @Environment(\.festivalEdition) private var edition
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.festivalData) private var festivalData
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject var profile: FestivalProfileStore

    @State private var isShowingNoteEditor = false
    @State private var isEditAlertShown = false
    @State private var noteDraft = ArtistNoteDraft(noteText: nil)
    @State private var presentedBrowserURL: PresentedBrowserURL?
    @State private var isArtistTitleVisible = true
    @StateObject private var appleMusicPreviewPlayer = AppleMusicPreviewPlayer()
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.artistDetailScreen
    )
    @ScaledMetric(relativeTo: .body) private var minimumInformationWidth: CGFloat = 360

    init(
        artist: Artist,
        highlightedEventId: Int?,
        navigate: ((AppNavigationRoute) -> Void)? = nil
    ) {
        self.artist = artist
        self.highlightedEventId = highlightedEventId
        self.navigate = navigate
    }

    var artistEvents: [Event] {
        festivalData.programDetails.artistEvents(id: artist.artistID)
    }

    var artistNote: String? {
        profile.noteText(for: artist)
    }

    private var horizontalContentMargin: CGFloat {
        horizontalSizeClass == .regular
            ? Layout.regularHorizontalMargin
            : Layout.compactHorizontalMargin
    }

    private var usesEdgeToEdgeHero: Bool {
        isPhone
            && horizontalSizeClass == .compact
            && verticalSizeClass == .regular
            && !dynamicTypeSize.isAccessibilitySize
    }

    private var isPhone: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    private var navigationBarBackgroundVisibility: Visibility {
        usesEdgeToEdgeHero && isArtistTitleVisible ? .hidden : .automatic
    }

    private func presentNoteEditor() {
        guard !profile.isReadOnly, artist.isMetadataAvailable else { return }
        noteDraft = ArtistNoteDraft(noteText: artistNote)
        isEditAlertShown = false
        isShowingNoteEditor = true
    }

    private func requestNoteEditorDismissal() {
        if noteDraft.hasChanges {
            isEditAlertShown = true
        } else {
            isShowingNoteEditor = false
        }
    }

    private func saveNote() {
        if noteDraft.hasChanges {
            profile.setArtistNote(for: artist, note: noteDraft.text)
        }
        isShowingNoteEditor = false
    }

    private func discardNoteChanges() {
        isEditAlertShown = false
        isShowingNoteEditor = false
    }

    private var artistTheme: ArtistDetailTheme {
        .fallback(for: systemColorScheme)
    }

    private var primarySectionSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 24 : 20
    }

    private var onCountrySelected: ((String) -> Void)? {
        guard let navigate else {
            return nil
        }
        return { countryCode in
            navigate(.artistCountry(code: countryCode))
        }
    }

    private func primaryContent(showsInlineIdentity: Bool) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ArtistDetailHeaderView(
                artist: artist,
                showsInlineIdentity: showsInlineIdentity,
                currentTipID: tipSequencer.currentTipID,
                onTitleVisibilityChange: { isVisible in
                    isArtistTitleVisible = isVisible
                },
                onCountrySelected: onCountrySelected
            )

            ArtistDetailIntroView(
                artist: artist,
                note: artistNote,
                currentTipID: tipSequencer.currentTipID,
                topPadding: showsInlineIdentity
                    ? primarySectionSpacing
                    : Layout.edgeToEdgeIntroTopSpacing,
                onEditNote: {
                    presentNoteEditor()
                }
            )
            .disabled(!artist.isMetadataAvailable)

            ArtistDetailLinksView(
                artist: artist,
                topPadding: primarySectionSpacing,
                previewPlayer: appleMusicPreviewPlayer
            ) { url in
                presentedBrowserURL = PresentedBrowserURL(url: url)
            }

            if !artistEvents.isEmpty {
                ArtistEventsBlock(
                    artistEvents: artistEvents,
                    highlightedEventId: highlightedEventId,
                    currentTipID: tipSequencer.currentTipID,
                    navigate: navigate,
                    horizontalHighlightBleed: horizontalContentMargin
                )
                .padding(.top, primarySectionSpacing)
            }

            if
                let videoURL = artist.videoUrl,
                let videoID = extractYouTubeVideoID(from: videoURL)
            {
                ArtistYouTubeVideoView(
                    videoID: videoID,
                    videoURL: videoURL
                )
                .padding(.top, primarySectionSpacing)
            }
        }
        .padding(.top, showsInlineIdentity ? 8 : 0)
    }

    private func contentColumn<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: Layout.maximumContentWidth, alignment: .leading)
            .padding(.horizontal, horizontalContentMargin)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var edgeToEdgeHero: some View {
        GeometryReader { proxy in
            let scrollOffset = max(
                -proxy.frame(in: .scrollView(axis: .vertical)).minY,
                0
            )
            ArtistDetailImageView(
                artist: artist,
                presentation: .edgeToEdgeParallax
            )
            .overlay { DetailHeroScrim() }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 12) {
                    DetailHeroHeader(
                        title: artist.formattedName,
                        onTitleVisibilityChange: { isArtistTitleVisible = $0 }
                    ) {
                        ArtistCountryTagsView(
                            artist: artist,
                            appearance: .overImage,
                            onCountrySelected: onCountrySelected
                        )
                    }
                    .layoutPriority(1)

                    ArtistRatingPopoverButton(
                        artist: artist,
                        currentTipID: tipSequencer.currentTipID
                    )
                }
                .padding(.horizontal, Layout.compactHorizontalMargin)
                .padding(.bottom, 20)
                .modifier(
                    DetailHeroIdentityFade(scrollOffset: scrollOffset, heroHeight: proxy.size.height)
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func detailLayout(availableWidth: CGFloat) -> some View {
        let canUseColumns = isPhone
            && verticalSizeClass == .compact
            && !dynamicTypeSize.isAccessibilitySize
            && availableWidth >= Layout.minimumImageColumnWidth
                + minimumInformationWidth + 3 * horizontalContentMargin

        if #available(iOS 16.0, macOS 13.0, *), canUseColumns {
            ViewThatFits(in: .vertical) {
                HStack(alignment: .top, spacing: 0) {
                    ArtistDetailProfileView(
                        artist: artist,
                        currentTipID: tipSequencer.currentTipID,
                        onCountrySelected: onCountrySelected
                    )
                    .frame(width: min(
                        Layout.maximumImageColumnWidth,
                        max(Layout.minimumImageColumnWidth, availableWidth / 3)
                    ))
                    .padding(.leading, horizontalContentMargin)
                    .padding(.vertical, 12)
                    .onAppear { isArtistTitleVisible = true }

                    detailScrollView(showsProfile: false)
                        // Only the fixed profile determines the required height.
                        .frame(idealHeight: 0)
                }

                detailScrollView(showsProfile: true)
            }
        } else {
            detailScrollView(showsProfile: true)
        }
    }

    private func detailScrollView(showsProfile: Bool) -> some View {
        let showsHero = usesEdgeToEdgeHero && showsProfile

        return ScrollView {
            LazyVStack(spacing: 0) {
                if showsHero {
                    edgeToEdgeHero
                }

                contentColumn {
                    primaryContent(showsInlineIdentity: showsProfile && !showsHero)
                }
                .background(artistTheme.pageBackground)

                contentColumn {
                    ArtistDetailSupportingContent(artist: artist, sectionSpacing: primarySectionSpacing)
                }
                .background(artistTheme.pageBackground)
            }
        }
        .ignoresSafeArea(
            .container,
            edges: showsHero ? .top : []
        )
        .modifier(
            DetailTopScrollEdgeEffect(
                isHidden: showsHero && isArtistTitleVisible
            )
        )
    }

    @ViewBuilder
    private func shareButton(url: URL) -> some View {
        if #available(macOS 13.0, *) {
            ShareLink(item: url, subject: Text(artist.formattedName)) {
                Label("artist.share", systemImage: "square.and.arrow.up")
            }
        } else {
            #if os(macOS)
            Menu {
                ForEach(NSSharingService.sharingServices(forItems: [url]), id: \.self) { service in
                    Button(service.title) {
                        service.perform(withItems: [url])
                    }
                }
            } label: {
                Label("artist.share", systemImage: "square.and.arrow.up")
            }
            #endif
        }
    }

    var body: some View {
        GeometryReader { geometry in
            detailLayout(availableWidth: geometry.size.width)
        }
        #if os(iOS)
            .modifier(FriendArtistRatingsPresentationModifier(artistName: artist.formattedName))
        #endif
            .environment(\.artistDetailTheme, artistTheme)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(
                "artist-detail-\(artist.id)-theme-ready"
            )
            .background(artistTheme.pageBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(isArtistTitleVisible ? "" : artist.formattedName)
            .toolbarBackgroundVisibility(
                navigationBarBackgroundVisibility,
                for: .navigationBar
            )
            .toolbarColorScheme(nil, for: .navigationBar)
            .toolbar {
                if let url = dataStore.adapter.services.publicLinks.value?.url(for: .artist(artist.id)) {
                    ToolbarItem(placement: .primaryAction) {
                        shareButton(url: url)
                            .accessibilityIdentifier("artist-share")
                    }
                }
            }
            .sheet(isPresented: $isShowingNoteEditor) {
                ArtistNoteEditorView(
                    noteText: $noteDraft.text,
                    onCancel: requestNoteEditorDismissal,
                    onSave: saveNote
                )
                .interactiveDismissDisabled(noteDraft.hasChanges)
                .alert(isPresented: $isEditAlertShown) {
                    Alert(
                        title: Text("artist.note.cancel.alert.title"),
                        message: Text("artist.note.cancel.alert.message"),
                        primaryButton: .destructive(
                            Text("artist.note.cancel.alert.yes"),
                            action: discardNoteChanges
                        ),
                        secondaryButton: .cancel(
                            Text("artist.note.cancel.alert.no")
                        ) {
                            isEditAlertShown = false
                        }
                    )
                }
            }
            .onReceive(profile.objectWillChange) {
                if isShowingNoteEditor {
                    noteDraft.receiveSavedNote(profile.state.notes[String(artist.id)])
                }
            }
            .sheet(item: $presentedBrowserURL) { destination in
                InAppSafariView(url: destination.url)
                    .ignoresSafeArea()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase != .active {
                    appleMusicPreviewPlayer.pause()
                }
            }
            .onDisappear {
                appleMusicPreviewPlayer.stop()
            }
    }
}

struct ArtistNoteDraft: Equatable {
    private(set) var originalText: String
    var text: String

    init(noteText: String?) {
        originalText = noteText ?? ""
        text = originalText
    }

    var hasChanges: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            != originalText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func receiveSavedNote(_ note: String?) {
        guard !hasChanges else { return }
        self = ArtistNoteDraft(noteText: note)
    }
}

private var confirmationButtonRole: ButtonRole? {
    if #available(iOS 26.0, *) {
        .confirm
    } else {
        nil
    }
}

private struct ArtistDetailSupportingContent: View {
    let artist: Artist
    let sectionSpacing: CGFloat
    @Environment(\.festivalData) private var festivalData
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let similarArtists = festivalData.programDetails.similarArtists(id: artist.artistID, limit: 5)

        return VStack(spacing: 0) {
            ArtistDescriptionBlock(
                description: artist.formattedDescription
            )
            .padding(.top, dynamicTypeSize.isAccessibilitySize ? 28 : 24)

            if !similarArtists.isEmpty {
                ArtistSimilarArtistsBlock(artists: similarArtists)
                    .padding(.top, sectionSpacing)
            }
        }
        .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 24 : 20)
    }
}

private struct ArtistNoteEditorView: View {
    @Binding var noteText: String
    let onCancel: () -> Void
    let onSave: () -> Void

    @EnvironmentObject private var profileSync: FestivalProfileSyncStore

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isEditorFocused: Bool

    private var noteFont: Font {
        .custom(
            "PatrickHand-Regular",
            size: 20,
            relativeTo: .body
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if profileSync.shouldWarnBeforeEditing {
                    Label("artist.note.sync-warning", systemImage: "exclamationmark.icloud")
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.background)
                        .accessibilityIdentifier("artist-note-sync-warning")
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $noteText)
                        .font(noteFont)
                        .scrollContentBackground(.hidden)
                        .focused($isEditorFocused)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)

                    if noteText.isEmpty {
                        Text("artist.note.placeholder")
                            .font(noteFont)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
            }
            .background { sheetBackground }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("artist.edit-note.headline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel, action: onCancel) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text("artist.note.cancel"))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(
                        role: confirmationButtonRole,
                        action: saveEditing
                    ) {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(Text("artist.note.save"))
                }
            }
        }
        .task {
            isEditorFocused = true
        }
    }

    private var sheetBackground: some View {
        ZStack {
            if colorScheme == .dark {
                Color(red: 0.31, green: 0.28, blue: 0.16)
            } else {
                Color(red: 1.00, green: 0.96, blue: 0.72)
            }

            Image(decorative: "artist-note-paper-texture")
                .resizable(resizingMode: .tile)
                .blendMode(.multiply)
                .opacity(colorScheme == .dark ? 0.30 : 0.52)
        }
        .ignoresSafeArea()
    }

    private func saveEditing() {
        isEditorFocused = false
        onSave()
    }
}

#if DEBUG
struct ArtistDetailView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        NavigationStack {
            ArtistDetailView(
                artist: PreviewMockData.featuredArtist,
                highlightedEventId: PreviewMockData.highlightedArtistEventID
            )
        }
        .previewMockEnvironment(suiteName: "ArtistDetailViewPreviewProfile")
    }
}
#endif
