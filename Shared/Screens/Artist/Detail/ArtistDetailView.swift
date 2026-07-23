import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ArtistDetailView: View {
    private enum Layout {
        static let maximumContentWidth: CGFloat = 720
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

    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.festivalData) private var festivalData
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject var profile: FestivalProfileStore

    @State private var isShowingNoteEditView = false
    @State var isEditAlertShown: Bool = false
    @State private var noteDraft = ArtistNoteDraft(noteText: nil)
    @State private var presentedBrowserURL: PresentedBrowserURL?
    @State private var isArtistTitleVisible = true
    @State private var artistRatingViewportHeight: CGFloat = 0
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
        isShowingNoteEditView = true
    }

    private func requestNoteEditorDismissal() {
        if noteDraft.hasChanges {
            isEditAlertShown = true
        } else {
            isShowingNoteEditView = false
        }
    }

    private func saveNote() {
        profile.setArtistNote(for: artist, note: noteDraft.text)
        isShowingNoteEditView = false
    }

    private func discardNoteChanges() {
        isEditAlertShown = false
        isShowingNoteEditView = false
    }

    private var artistTheme: ArtistDetailTheme {
        .fallback(for: systemColorScheme)
    }

    private var primarySectionSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 24 : 20
    }

    private func primaryContent(showsInlineIdentity: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ArtistDetailHeaderView(
                artist: artist,
                showsInlineIdentity: showsInlineIdentity,
                currentTipID: tipSequencer.currentTipID,
                onTitleVisibilityChange: { isVisible in
                    isArtistTitleVisible = isVisible
                }
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
                    navigate: navigate
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
        VStack(spacing: 0) {
            ArtistDescriptionBlock(
                description: artist.formattedDescription
            )
            .padding(.top, dynamicTypeSize.isAccessibilitySize ? 28 : 24)
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
                Text(artist.formattedName)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                    .accessibilityHeading(.h1)
                    .onScrollVisibilityChange(threshold: 0.1) { isVisible in
                        isArtistTitleVisible = isVisible
                    }
                    .allowsHitTesting(false)

                ArtistRatingPopoverButton(
                    artist: artist,
                    currentTipID: tipSequencer.currentTipID
                )
            }
            .padding(.horizontal, Layout.compactHorizontalMargin)
            .padding(.bottom, 20)
        }
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

    var body: some View {
        detailScrollView
            .coordinateSpace(name: ArtistRatingCoordinateSpace.name)
            .environment(\.artistDetailTheme, artistTheme)
            .environment(
                \.artistRatingViewportHeight,
                artistRatingViewportHeight
            )
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
            .fullScreenCover(isPresented: $isShowingNoteEditView) {
                ZStack {
                    Color.black
                        .opacity(
                            systemColorScheme == .dark ? 0.50 : 0.36
                        )
                        .ignoresSafeArea()

                    ArtistNoteEditorView(
                        noteText: $noteDraft.text,
                        onCancel: requestNoteEditorDismissal,
                        onSave: saveNote
                    )
                    .alert(isPresented: $isEditAlertShown) {
                        Alert(
                            title: Text(
                                "artist.note.cancel.alert.title"
                            ),
                            message: Text(
                                "artist.note.cancel.alert.message"
                            ),
                            primaryButton: .destructive(
                                Text(
                                    "artist.note.cancel.alert.yes"
                                ),
                                action: discardNoteChanges
                            ),
                            secondaryButton: .cancel(
                                Text(
                                    "artist.note.cancel.alert.no"
                                )
                            ) {
                                isEditAlertShown = false
                            }
                        )
                    }
                }
                .presentationBackground(.clear)
            }
            .sheet(item: $presentedBrowserURL) { destination in
                InAppSafariView(url: destination.url)
                    .ignoresSafeArea()
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { newHeight in
                artistRatingViewportHeight = newHeight
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

    @FocusState private var isEditorFocused: Bool

    private let foldSize: CGFloat = 34
    private let maximumEditorWidth: CGFloat = 680

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                editorButton(
                    systemImage: "xmark",
                    accessibilityLabel: "artist.note.cancel",
                    role: .cancel,
                    action: onCancel
                )

                Text("artist.edit-note.headline")
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                editorButton(
                    systemImage: "checkmark",
                    accessibilityLabel: "artist.note.save",
                    role: confirmationButtonRole,
                    action: saveEditing
                )
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $noteText)
                    .font(
                        .custom(
                            "Noteworthy-Light",
                            size: 20,
                            relativeTo: .body
                        )
                    )
                    .scrollContentBackground(.hidden)
                    .focused($isEditorFocused)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .padding(.bottom, foldSize * 0.6)

                if noteText.isEmpty {
                    Text("artist.note.placeholder")
                        .font(
                            .custom(
                                "Noteworthy-Light",
                                size: 20,
                                relativeTo: .body
                            )
                        )
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: maximumEditorWidth, maxHeight: .infinity)
        .background {
            ArtistNotePaperBackground(foldSize: foldSize)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            isEditorFocused = true
        }
    }

    private func editorButton(
        systemImage: String,
        accessibilityLabel: LocalizedStringKey,
        role: ButtonRole?,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
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
