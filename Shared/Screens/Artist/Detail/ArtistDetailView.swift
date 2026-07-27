import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

private enum ArtistNoteFocusTarget: Hashable {
    case keyboardKeeper
    case editor
}

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

    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.festivalData) private var festivalData
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject var profile: FestivalProfileStore

    @State private var isShowingCenteredNote = false
    @State private var isShowingLiveNoteEditor = false
    @State private var isNotePreviewHidden = false
    @State var isEditAlertShown: Bool = false
    @State private var noteDraft = ArtistNoteDraft(noteText: nil)
    @State private var noteMoveProgress: CGFloat = 0
    @State private var notePreviewFrame: CGRect = .zero
    @State private var notePreviewUnrotatedSize: CGSize = .zero
    @State private var centeredNoteKeyboardTop: CGFloat?
    @State private var centeredNoteSafeAreaTop: CGFloat?
    @State private var centeredNoteDestinationFrame: CGRect?
    @State private var isWaitingForKeyboardTarget = false
    @State private var presentedBrowserURL: PresentedBrowserURL?
    @State private var isArtistTitleVisible = true
    @State private var artistRatingViewportHeight: CGFloat = 0
    @StateObject private var appleMusicPreviewPlayer = AppleMusicPreviewPlayer()
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.artistDetailScreen
    )
    @FocusState private var noteFocusTarget: ArtistNoteFocusTarget?

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

    private func presentCenteredNote() {
        guard !isShowingCenteredNote, !notePreviewFrame.isEmpty else {
            return
        }

        noteDraft = ArtistNoteDraft(noteText: artistNote)

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            noteMoveProgress = 0
            centeredNoteKeyboardTop = nil
            centeredNoteSafeAreaTop = nil
            centeredNoteDestinationFrame = nil
            isWaitingForKeyboardTarget = true
            isShowingLiveNoteEditor = false
            isEditAlertShown = false
            isNotePreviewHidden = true
            isShowingCenteredNote = true
        }

        Task { @MainActor in
            await Task.yield()
            guard isShowingCenteredNote else {
                return
            }
            noteFocusTarget = .keyboardKeeper
        }
    }

    private func dismissCenteredNote() {
        isWaitingForKeyboardTarget = false
        if isShowingLiveNoteEditor {
            guard noteFocusTarget != .keyboardKeeper else {
                return
            }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                noteFocusTarget = .keyboardKeeper
            }

            Task { @MainActor in
                await Task.yield()
                guard
                    isShowingCenteredNote,
                    noteFocusTarget == .keyboardKeeper
                else {
                    return
                }

                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isShowingLiveNoteEditor = false
                }
                beginCenteredNoteDismissalAnimation()
            }
            return
        }

        beginCenteredNoteDismissalAnimation()
    }

    private func beginCenteredNoteDismissalAnimation() {
        withAnimation(
            noteMoveAnimation,
            completionCriteria: .removed
        ) {
            noteMoveProgress = 0
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                noteFocusTarget = nil
                isShowingCenteredNote = false
                isNotePreviewHidden = false
            }
        }
    }

    private func requestNoteEditorDismissal() {
        if noteDraft.hasChanges {
            isEditAlertShown = true
        } else {
            dismissCenteredNote()
        }
    }

    private func saveNote() {
        profile.setArtistNote(for: artist, note: noteDraft.text)
        dismissCenteredNote()
    }

    private func discardNoteChanges() {
        isEditAlertShown = false
        noteDraft = ArtistNoteDraft(noteText: artistNote)
        dismissCenteredNote()
    }

    private var noteDiscardAlert: Alert {
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

    private func notePreviewFrameChanged(
        _ geometry: ArtistNotePreviewGeometry
    ) {
        guard !geometry.frame.isEmpty, !isShowingCenteredNote else {
            return
        }
        notePreviewFrame = geometry.frame
        notePreviewUnrotatedSize = geometry.unrotatedSize
    }

    private func keyboardWillChangeFrame(_ notification: Notification) {
        guard
            isWaitingForKeyboardTarget,
            let keyboardFrame = notification.userInfo?[
                UIResponder.keyboardFrameEndUserInfoKey
            ] as? CGRect,
            let window = activeWindow
        else {
            return
        }

        let safeAreaTop = window.frame.minY + window.safeAreaInsets.top
        let keyboardTop = min(
            max(keyboardFrame.minY, safeAreaTop),
            window.frame.maxY
        )
        let destinationFrame = ArtistNoteEditorLayout.paperFrame(
            in: window.frame,
            safeAreaInsets: EdgeInsets(
                top: window.safeAreaInsets.top,
                leading: window.safeAreaInsets.left,
                bottom: window.safeAreaInsets.bottom,
                trailing: window.safeAreaInsets.right
            ),
            keyboardTop: keyboardTop
        )

        centeredNoteKeyboardTop = keyboardTop
        centeredNoteSafeAreaTop = safeAreaTop
        centeredNoteDestinationFrame = destinationFrame
        startCenteredNoteMovement()
    }

    private var activeWindow: UIWindow? {
        let foregroundScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        return foregroundScenes
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow)
    }

    private func startCenteredNoteMovement() {
        isWaitingForKeyboardTarget = false
        withAnimation(
            noteMoveAnimation,
            completionCriteria: .removed
        ) {
            noteMoveProgress = 1
        } completion: {
            handOffToLiveNoteEditor()
        }
    }

    private func handOffToLiveNoteEditor() {
        guard isShowingCenteredNote, noteMoveProgress == 1 else {
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isShowingLiveNoteEditor = true
            noteFocusTarget = .editor
        }
    }

    private var noteMoveAnimation: Animation? {
        accessibilityReduceMotion
            ? nil
            : .easeOut(duration: 0.24)
    }

    private var centeredNoteFoldSize: CGFloat {
        noteDraft.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty ? 10 : 17
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
                    presentCenteredNote()
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

    var body: some View {
        detailScrollView
            .allowsHitTesting(!isShowingCenteredNote)
            .accessibilityHidden(isShowingCenteredNote)
            .coordinateSpace(name: ArtistRatingCoordinateSpace.name)
            .environment(\.artistDetailTheme, artistTheme)
            .environment(
                \.artistNotePreviewFrameHandler,
                notePreviewFrameChanged
            )
            .environment(
                \.isArtistNotePreviewHidden,
                isNotePreviewHidden
            )
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
            .overlay {
                if isShowingCenteredNote {
                    GeometryReader { proxy in
                        let overlayOrigin = proxy.frame(in: .global).origin
                        let sourceCenter = CGPoint(
                            x: notePreviewFrame.midX - overlayOrigin.x,
                            y: notePreviewFrame.midY - overlayOrigin.y
                        )
                        let fallbackDestinationFrame =
                            ArtistNoteEditorLayout.paperFrame(
                                in: proxy.frame(in: .global),
                                safeAreaInsets: proxy.safeAreaInsets,
                                keyboardTop: centeredNoteKeyboardTop
                            )
                        let safeAreaTop = centeredNoteSafeAreaTop
                            ?? (
                                overlayOrigin.y
                                    + proxy.safeAreaInsets.top
                            )
                        let destinationGlobalFrame =
                            centeredNoteDestinationFrame
                                ?? fallbackDestinationFrame
                        let destinationTop = max(
                            destinationGlobalFrame.minY,
                            overlayOrigin.y
                                + ArtistNoteEditorLayout.topPadding
                        )
                        let visibleDestinationGlobalFrame = CGRect(
                            x: destinationGlobalFrame.minX,
                            y: destinationTop,
                            width: destinationGlobalFrame.width,
                            height: max(
                                destinationGlobalFrame.maxY
                                    - destinationTop,
                                0
                            )
                        )
                        let destinationFrame =
                            visibleDestinationGlobalFrame.offsetBy(
                                dx: -overlayOrigin.x,
                                dy: -overlayOrigin.y
                            )
                        let destinationCenter = CGPoint(
                            x: destinationFrame.midX,
                            y: destinationFrame.midY
                        )
                        let textReflowProgress =
                            ArtistNoteMotionGeometry.textReflowProgress(
                                for: noteMoveProgress
                            )
                        let currentPaperHeight =
                            ArtistNoteMotionGeometry.interpolate(
                                from: notePreviewUnrotatedSize.height,
                                to: destinationFrame.height,
                                progress: noteMoveProgress
                            )
                        let currentPaperWidth =
                            ArtistNoteMotionGeometry.interpolate(
                                from: notePreviewUnrotatedSize.width,
                                to: destinationFrame.width,
                                progress: noteMoveProgress
                            )
                        let currentCurveCenter =
                            ArtistNoteMotionGeometry.point(
                                progress: noteMoveProgress,
                                start: sourceCenter,
                                end: destinationCenter,
                                minimumY: safeAreaTop
                                    - overlayOrigin.y
                                    + notePreviewUnrotatedSize.height / 2
                            )
                        let currentPaperCenter = CGPoint(
                            x: currentCurveCenter.x,
                            y: max(
                                currentCurveCenter.y,
                                safeAreaTop
                                    - overlayOrigin.y
                                    + currentPaperHeight / 2
                            )
                        )
                        let editorTextScale = min(
                            currentPaperWidth
                                / max(destinationFrame.width, 1),
                            currentPaperHeight
                                / max(destinationFrame.height, 1)
                        )
                        let currentPaperRotation =
                            ArtistNoteMotionGeometry.interpolate(
                                from:
                                    ArtistNoteMotionGeometry
                                        .previewRotation,
                                to: 0,
                                progress: noteMoveProgress
                            )
                        Color.black
                            .opacity(
                                (
                                    systemColorScheme == .dark
                                        ? 0.50
                                        : 0.36
                                ) * noteMoveProgress
                            )
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isShowingLiveNoteEditor {
                                    requestNoteEditorDismissal()
                                } else {
                                    dismissCenteredNote()
                                }
                            }

                        ArtistNoteGrowingPaper(
                            progress: noteMoveProgress,
                            start: sourceCenter,
                            end: destinationCenter,
                            sourceSize: notePreviewUnrotatedSize,
                            destinationSize: destinationFrame.size,
                            sourceFoldSize: centeredNoteFoldSize,
                            safeAreaTop: safeAreaTop - overlayOrigin.y
                        )

                        ArtistNoteEditorSurface(
                            noteText: $noteDraft.text,
                            focusTarget: $noteFocusTarget,
                            onCancel: requestNoteEditorDismissal,
                            onSave: saveNote
                        )
                        .frame(
                            width: destinationFrame.width,
                            height: destinationFrame.height
                        )
                        .position(destinationCenter)
                        .opacity(isShowingLiveNoteEditor ? 1 : 0)
                        .allowsHitTesting(isShowingLiveNoteEditor)
                        .accessibilityHidden(!isShowingLiveNoteEditor)
                        .alert(isPresented: $isEditAlertShown) {
                            noteDiscardAlert
                        }

                        if !isShowingLiveNoteEditor {
                            ArtistNoteBlock(
                                note: noteDraft.text,
                                showsPaper: false,
                                onEdit: {}
                            )
                            .environment(
                                \.isArtistNotePreviewHidden,
                                false
                            )
                            .environment(
                                \.artistNotePreviewFrameHandler,
                                { _ in }
                            )
                            .position(sourceCenter)
                            .modifier(
                                ArtistNoteCurveMotion(
                                    progress: noteMoveProgress,
                                    start: sourceCenter,
                                    end: destinationCenter,
                                    sourceHeight:
                                        notePreviewUnrotatedSize.height,
                                    destinationHeight:
                                        destinationFrame.height,
                                    safeAreaTop:
                                        safeAreaTop - overlayOrigin.y
                                )
                            )
                            .rotationEffect(
                                .degrees(
                                    -ArtistNoteMotionGeometry
                                        .previewRotation
                                        * Double(noteMoveProgress)
                                )
                            )
                            .scaleEffect(
                                ArtistNoteMotionGeometry
                                    .scaledPreviewTextScale(
                                        for: noteMoveProgress
                                    )
                            )
                            .opacity(1 - textReflowProgress)

                            ArtistNoteEditorTextLayer(
                                noteText: noteDraft.text
                            )
                            .frame(
                                width: destinationFrame.width,
                                height: destinationFrame.height
                            )
                            .scaleEffect(editorTextScale)
                            .rotationEffect(
                                .degrees(Double(currentPaperRotation))
                            )
                            .position(currentPaperCenter)
                            .opacity(textReflowProgress)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                        }

                        TextEditor(text: $noteDraft.text)
                            .focused(
                                $noteFocusTarget,
                                equals: .keyboardKeeper
                            )
                            .scrollContentBackground(.hidden)
                            .frame(width: 1, height: 1)
                            .opacity(0.01)
                            .position(destinationCenter)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    .accessibilityAction(.escape, dismissCenteredNote)
                    .ignoresSafeArea(.keyboard)
                }
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
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillChangeFrameNotification
                ),
                perform: keyboardWillChangeFrame
            )
            .onDisappear {
                appleMusicPreviewPlayer.stop()
            }
    }
}

private enum ArtistNoteEditorLayout {
    static let maximumWidth: CGFloat = 680
    static let horizontalPadding: CGFloat = 16
    static let topPadding: CGFloat = 12
    static let bottomPadding: CGFloat = 16

    static func paperFrame(
        in presentationFrame: CGRect,
        safeAreaInsets: EdgeInsets,
        keyboardTop: CGFloat?
    ) -> CGRect {
        let availableWidth = max(
            presentationFrame.width - 2 * horizontalPadding,
            0
        )
        let width = min(availableWidth, maximumWidth)
        let top = presentationFrame.minY
            + safeAreaInsets.top
            + topPadding
        let presentationBottom = presentationFrame.maxY
            - safeAreaInsets.bottom
        let keyboardBoundary = min(
            max(keyboardTop ?? presentationBottom, top),
            presentationBottom
        )
        let bottom = max(keyboardBoundary - bottomPadding, top)

        return CGRect(
            x: presentationFrame.midX - width / 2,
            y: top,
            width: width,
            height: bottom - top
        )
    }
}

private struct ArtistNoteCurveMotion: GeometryEffect {
    var progress: CGFloat
    let start: CGPoint
    let end: CGPoint
    let sourceHeight: CGFloat
    let destinationHeight: CGFloat
    let safeAreaTop: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size _: CGSize) -> ProjectionTransform {
        let height = ArtistNoteMotionGeometry.interpolate(
            from: sourceHeight,
            to: destinationHeight,
            progress: progress
        )
        let curvePoint = ArtistNoteMotionGeometry.point(
            progress: progress,
            start: start,
            end: end,
            minimumY: safeAreaTop + sourceHeight / 2
        )
        let point = CGPoint(
            x: curvePoint.x,
            y: max(curvePoint.y, safeAreaTop + height / 2)
        )

        return ProjectionTransform(
            CGAffineTransform(
                translationX: point.x - start.x,
                y: point.y - start.y
            )
        )
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

private enum ArtistNoteEditorContentLayout {
    static let foldSize: CGFloat = 34
    static let toolbarHeight: CGFloat = 52

    static var noteFont: Font {
        .custom(
            "Noteworthy-Light",
            size: 20,
            relativeTo: .body
        )
    }
}

private struct ArtistNoteEditorTextLayer: View {
    let noteText: String

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: ArtistNoteEditorContentLayout.toolbarHeight)

            ZStack(alignment: .topLeading) {
                TextEditor(text: .constant(noteText))
                    .font(ArtistNoteEditorContentLayout.noteFont)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .padding(
                        .bottom,
                        ArtistNoteEditorContentLayout.foldSize * 0.6
                    )

                if noteText.isEmpty {
                    Text("artist.note.placeholder")
                        .font(ArtistNoteEditorContentLayout.noteFont)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipped()
    }
}

private struct ArtistNoteEditorSurface: View {
    @Binding var noteText: String
    let focusTarget: FocusState<ArtistNoteFocusTarget?>.Binding
    let onCancel: () -> Void
    let onSave: () -> Void

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
                    .font(ArtistNoteEditorContentLayout.noteFont)
                    .scrollContentBackground(.hidden)
                    .focused(focusTarget, equals: .editor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .padding(
                        .bottom,
                        ArtistNoteEditorContentLayout.foldSize * 0.6
                    )

                if noteText.isEmpty {
                    Text("artist.note.placeholder")
                        .font(ArtistNoteEditorContentLayout.noteFont)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
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
