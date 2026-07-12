import MusicKit
import SwiftUI

struct ArtistDetailView: View {
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
    @EnvironmentObject var profile: FestivalProfileStore

    @State private var isShowingNoteEditView = false
    @State var isEditAlertShown: Bool = false
    @State var noteText: String = ""
    @State private var isShowingAIInfo = false
    @State private var presentedBrowserURL: PresentedBrowserURL?
    @State private var isArtistTitleVisible = true
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.artistDetailScreen
    )

    @State private var artistTheme: ArtistDetailTheme
    @State private var isArtistThemeReady = false

    init(
        artist: Artist,
        highlightedEventId: Int?,
        navigate: ((AppNavigationRoute) -> Void)? = nil
    ) {
        self.artist = artist
        self.highlightedEventId = highlightedEventId
        self.navigate = navigate
        _artistTheme = State(initialValue: .fallback(for: .light))
    }

    var artistEvents: [Event] {
        festivalData.events.filter {
            $0.artist.id == artist.id
        }
    }

    var artistNote: String? {
        profile.noteText(for: artist)
    }

    private var friendRatingSummary: FriendArtistRatingSummary? {
        profile.friendArtistRatingSummary(for: artist.id)
    }

    private func applyThemeColors(
        _ themeColors: ArtistImageThemeColors,
        for colorScheme: ColorScheme
    ) {
        let updateColors = {
            artistTheme = themeColors.artistDetailTheme(for: colorScheme)
            isArtistThemeReady = true
        }

        if ScreenshotRuntime.isEnabled {
            updateColors()
        } else {
            withAnimation(.easeInOut(duration: 0.25), updateColors)
        }
    }

    private func applyCachedColors(for colorScheme: ColorScheme) {
        guard
            let cachedThemeColors = ArtistImageColorCache.shared.cachedThemeColors(for: artist.id)
        else {
            return
        }

        applyThemeColors(cachedThemeColors, for: colorScheme)
    }

    private func loadArtistBackgroundColor() async {
        if ArtistImageColorCache.shared.cachedThemeColors(for: artist.id) != nil {
            applyCachedColors(for: systemColorScheme)
            return
        }

        guard let themeColors = await ArtistImageColorCache.shared.themeColors(for: artist) else {
            return
        }

        await MainActor.run {
            applyThemeColors(themeColors, for: systemColorScheme)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(
                    alignment: .leading,
                    spacing: dynamicTypeSize.isAccessibilitySize ? 14 : 18
                ) {
                    ArtistDetailHeaderView(
                        artist: artist,
                        friendRatingSummary: friendRatingSummary,
                        onTitleVisibilityChange: { isVisible in
                            isArtistTitleVisible = isVisible
                        }
                    )

                    ArtistDetailLinksView(artist: artist) { url in
                        presentedBrowserURL = PresentedBrowserURL(url: url)
                    }

                    ArtistRatingView(
                        artist: artist,
                        currentTipID: tipSequencer.currentTipID
                    )
                        .padding(
                            .horizontal,
                            dynamicTypeSize.isAccessibilitySize ? 0 : 34
                        )
                        .frame(maxWidth: .infinity)

                    ArtistNoteBlock(note: artistNote) {
                        isShowingNoteEditView = true
                    }
                    ArtistEventsBlock(
                        artistEvents: artistEvents,
                        highlightedEventId: highlightedEventId,
                        currentTipID: tipSequencer.currentTipID,
                        navigate: navigate
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 18)

                VStack(spacing: 0) {
                    ArtistAISummaryBlock(artist: artist)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 2)

                    ArtistDescriptionBlock(
                        description: artist.formattedDescription
                    )
                }
                .background(artistTheme.descriptionSurface)
            }
        }
        .environment(\.artistDetailTheme, artistTheme)
        .accessibilityIdentifier(
            "artist-detail-\(artist.id)-theme-\(isArtistThemeReady ? "ready" : "loading")"
        )
        .background(artistTheme.pageBackground.ignoresSafeArea())
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            applyCachedColors(for: systemColorScheme)
        }
        .onChange(of: systemColorScheme, initial: false) { _, _ in
            isArtistThemeReady = false
            applyCachedColors(for: systemColorScheme)
        }
        .task(id: artist.id) {
            await loadArtistBackgroundColor()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(isArtistTitleVisible ? "" : artist.formattedName)
        .toolbar {
            ToolbarItem(placement: .principal) {
                EmptyView()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        isShowingNoteEditView.toggle()
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                    .appPopoverTip(
                        DiscoverabilityTips.artistNotes,
                        currentTipID: tipSequencer.currentTipID,
                        arrowEdge: .top
                    )
                }
            }
        }
        .sheet(isPresented: $isShowingNoteEditView) {
            NavigationView {
                ArtistNoteEditorView(noteText: $noteText)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("artist.edit-note.headline")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .cancel) {
                                if artistNote ?? "" == noteText {
                                    isShowingNoteEditView = false
                                } else {
                                    isEditAlertShown = true
                                }
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel(Text("artist.note.cancel"))
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(role: confirmationButtonRole) {
                                profile.setArtistNote(for: artist, note: noteText)
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
                                noteText = artistNote ?? ""
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
        .alert("artist.ai.header", isPresented: $isShowingAIInfo) {
            Button("artist.ai.info.ok", role: .cancel) {}
        } message: {
            Text("artist.ai.footer")
        }
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
