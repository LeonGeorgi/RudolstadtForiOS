import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ArtistDetailView: View {
    private enum Layout {
        static let maximumContentWidth: CGFloat = 720
        static let compactHorizontalMargin: CGFloat = 16
        static let regularHorizontalMargin: CGFloat = 24
        static let edgeToEdgeIntroTopSpacing: CGFloat = 12
        static let identityFadeStartFraction: CGFloat = 0.25
        static let identityFadeEndFraction: CGFloat = 0.70
    }

    private struct PresentedBrowserURL: Identifiable {
        let id = UUID()
        let url: URL
    }

    let artist: Artist
    let highlightedEventId: Int?
    let navigate: ((AppNavigationRoute) -> Void)?

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
        festivalData.events.filter {
            $0.artist.id == artist.id
        }
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
        profile.setArtistNote(for: artist, note: noteDraft.text)
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
        VStack(alignment: .leading, spacing: 0) {
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

    private var supportingContent: some View {
        let similarArtists = ArtistSimilarityCatalog.bundled.similarArtists(
            to: artist,
            among: festivalData.artists,
            festivalYear: DataStore.year
        )

        return VStack(spacing: 0) {
            ArtistDescriptionBlock(
                description: artist.formattedDescription
            )
            .padding(.top, dynamicTypeSize.isAccessibilitySize ? 28 : 24)

            if !similarArtists.isEmpty {
                ArtistSimilarArtistsBlock(artists: similarArtists)
                    .padding(.top, primarySectionSpacing)
            }
        }
        .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 24 : 20)
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
            let identityOpacity = edgeToEdgeIdentityOpacity(
                scrollOffset: scrollOffset,
                heroHeight: proxy.size.height
            )

            ArtistDetailImageView(
                artist: artist,
                presentation: .edgeToEdgeParallax
            )
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.68)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        ArtistCountryTagsView(
                            artist: artist,
                            appearance: .overImage,
                            onCountrySelected: onCountrySelected
                        )

                        Text(artist.formattedName)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                            .accessibilityHeading(.h1)
                            .onScrollVisibilityChange(
                                threshold: 0.1
                            ) { isVisible in
                                isArtistTitleVisible = isVisible
                            }
                            .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    ArtistRatingPopoverButton(
                        artist: artist,
                        currentTipID: tipSequencer.currentTipID
                    )
                }
                .padding(.horizontal, Layout.compactHorizontalMargin)
                .padding(.bottom, 20)
                .opacity(identityOpacity)
                .allowsHitTesting(identityOpacity > 0.01)
                .accessibilityHidden(identityOpacity <= 0.01)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func edgeToEdgeIdentityOpacity(
        scrollOffset: CGFloat,
        heroHeight: CGFloat
    ) -> Double {
        let fadeStart = heroHeight * Layout.identityFadeStartFraction
        let fadeEnd = heroHeight * Layout.identityFadeEndFraction
        let fadeProgress = (scrollOffset - fadeStart) / (fadeEnd - fadeStart)

        return Double(1 - min(max(fadeProgress, 0), 1))
    }

    private var detailScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                if usesEdgeToEdgeHero {
                    edgeToEdgeHero
                }

                contentColumn {
                    primaryContent(showsInlineIdentity: !usesEdgeToEdgeHero)
                }
                .background(artistTheme.pageBackground)

                contentColumn {
                    supportingContent
                }
                .background(artistTheme.pageBackground)
            }
        }
        .ignoresSafeArea(
            .container,
            edges: usesEdgeToEdgeHero ? .top : []
        )
        .modifier(
            ArtistDetailTopScrollEdgeEffectModifier(
                isHidden: usesEdgeToEdgeHero && isArtistTitleVisible
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
        detailScrollView
            .environment(\.artistDetailTheme, artistTheme)
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
                if let url = ArtistShareLink(year: DataStore.year, artistID: artist.id).url {
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

private struct ArtistDetailTopScrollEdgeEffectModifier: ViewModifier {
    let isHidden: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(isHidden, for: .top)
        } else {
            content
        }
    }
}

struct ArtistNoteDraft: Equatable {
    let originalText: String
    var text: String

    init(noteText: String?) {
        originalText = noteText ?? ""
        text = originalText
    }

    var hasChanges: Bool {
        text != originalText
    }
}

private var confirmationButtonRole: ButtonRole? {
    if #available(iOS 26.0, *) {
        .confirm
    } else {
        nil
    }
}

private struct ArtistNoteEditorView: View {
    @Binding var noteText: String
    let onCancel: () -> Void
    let onSave: () -> Void

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
            ZStack(alignment: .topLeading) {
                sheetBackground

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
