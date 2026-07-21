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
        isShowingNoteEditView = true
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
                topPadding: showsInlineIdentity
                    ? primarySectionSpacing
                    : Layout.edgeToEdgeIntroTopSpacing
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

            if let artistNote, !artistNote.isEmpty {
                ArtistNoteBlock(note: artistNote) {
                    presentNoteEditor()
                }
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: presentNoteEditor) {
                        Label(
                            "artist.edit-note.button",
                            systemImage: "square.and.pencil"
                        )
                        .labelStyle(.iconOnly)
                    }
                    .appPopoverTip(
                        DiscoverabilityTips.artistNotes,
                        currentTipID: tipSequencer.currentTipID,
                        arrowEdge: .top
                    )
                }
            }
            .sheet(isPresented: $isShowingNoteEditView) {
                NavigationStack {
                    ArtistNoteEditorView(noteText: $noteDraft.text)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("artist.edit-note.headline")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .cancel) {
                                if noteDraft.hasChanges {
                                    isEditAlertShown = true
                                } else {
                                    isShowingNoteEditView = false
                                }
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel(Text("artist.note.cancel"))
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(role: confirmationButtonRole) {
                                profile.setArtistNote(for: artist, note: noteDraft.text)
                                isShowingNoteEditView = false
                            } label: {
                                Image(systemName: "checkmark")
                            }
                            .accessibilityLabel(Text("artist.note.save"))
                        }
                    }
                    .alert(isPresented: $isEditAlertShown) {
                        Alert(
                            title: Text("artist.note.cancel.alert.title"),
                            message: Text("artist.note.cancel.alert.message"),
                            primaryButton: .destructive(
                                Text("artist.note.cancel.alert.yes")
                            ) {
                                isEditAlertShown = false
                                isShowingNoteEditView = false
                            },
                            secondaryButton: .cancel(
                                Text("artist.note.cancel.alert.no")
                            ) {
                                isEditAlertShown = false
                            }
                        )
                    }
                }
                .interactiveDismissDisabled()
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

    @Environment(\.colorScheme) private var colorScheme

    private var editorStrokeColor: Color {
        colorScheme == .dark ? .white.opacity(0.18) : .black.opacity(0.10)
    }

    private var editorShadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.18) : .black.opacity(0.06)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $noteText)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minHeight: 260, alignment: .topLeading)

                    if noteText.isEmpty {
                        Text("artist.note.placeholder")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(editorStrokeColor, lineWidth: 0.5)
                )
                .shadow(color: editorShadowColor, radius: 10, x: 0, y: 4)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
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
