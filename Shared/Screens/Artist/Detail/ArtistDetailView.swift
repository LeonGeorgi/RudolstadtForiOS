import MusicKit
import SwiftUI

struct ArtistDetailView: View {
    let artist: Artist
    let highlightedEventId: Int?

    @Environment(\.colorScheme) private var systemColorScheme
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var dataStore: DataStore

    @State private var isShowingNoteEditView = false
    @State var isEditAlertShown: Bool = false
    @State var noteText: String = ""
    @State private var isShowingAIInfo = false

    @Namespace private var imageViewerTransition

    @State private var artistBackgroundColor: Color
    @State private var descriptionBackgroundColor: Color
    @State private var descriptionBackgroundStartY = CGFloat.infinity

    init(artist: Artist, highlightedEventId: Int?) {
        self.artist = artist
        self.highlightedEventId = highlightedEventId
        _artistBackgroundColor = State(initialValue: .clear)
        _descriptionBackgroundColor = State(initialValue: .clear)
    }

    var artistEvents: LoadingEntity<[Event]> {
        dataStore.data.map { entities in
            entities.events.filter {
                $0.artist.id == artist.id
            }
        }
    }

    var artistNote: String? {
        settings.artistNotes["\(artist.id)"]
    }

    private func applyCachedColors(for colorScheme: ColorScheme) {
        guard
            let cachedThemeColors = ArtistImageColorCache.shared.cachedThemeColors(for: artist.id)
        else {
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            artistBackgroundColor = cachedThemeColors.backgroundColor(for: colorScheme)
            descriptionBackgroundColor = cachedThemeColors.descriptionBackgroundColor(for: colorScheme)
        }
    }

    private func loadArtistBackgroundColor() async {
        if let cachedThemeColors = ArtistImageColorCache.shared.cachedThemeColors(for: artist.id) {
            await MainActor.run {
                artistBackgroundColor = cachedThemeColors.backgroundColor(for: systemColorScheme)
                descriptionBackgroundColor = cachedThemeColors.descriptionBackgroundColor(for: systemColorScheme)
            }
            return
        }

        guard let themeColors = await ArtistImageColorCache.shared.themeColors(for: artist) else {
            return
        }

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.35)) {
                artistBackgroundColor = themeColors.backgroundColor(for: systemColorScheme)
                descriptionBackgroundColor = themeColors.descriptionBackgroundColor(for: systemColorScheme)
            }
        }
    }

    var body: some View {
        ZStack {
            ArtistDetailSplitBackground(
                artistBackgroundColor: artistBackgroundColor,
                descriptionBackgroundColor: descriptionBackgroundColor,
                descriptionBackgroundStartY: descriptionBackgroundStartY
            )

            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 18) {
                        ArtistDetailHeaderView(
                            artist: artist,
                            imageTransitionNamespace: imageViewerTransition
                        )

                        ArtistAISummaryBlock(artist: artist) {
                            isShowingAIInfo = true
                        }
                        ArtistDetailLinksView(artist: artist)
                        ArtistNoteBlock(note: artistNote) {
                            isShowingNoteEditView = true
                        }
                        ArtistEventsBlock(
                            artistEvents: artistEvents,
                            highlightedEventId: highlightedEventId
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 18)

                    ArtistDescriptionBlock(
                        description: artist.formattedDescription,
                        backgroundColor: descriptionBackgroundColor
                    )

                    ArtistBrowseGenresBlock(artist: artist)
                }
            }
        }
        .onPreferenceChange(DescriptionBackgroundStartPreferenceKey.self) { startY in
            descriptionBackgroundStartY = startY
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .onChange(of: systemColorScheme) {
            applyCachedColors(for: systemColorScheme)
        }
        .task(id: artist.id) {
            await loadArtistBackgroundColor()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        isShowingNoteEditView.toggle()
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingNoteEditView) {
            NavigationView {
                TextEditor(text: $noteText)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("artist.edit-note.headline")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("artist.note.cancel") {
                                if artistNote ?? "" == noteText {
                                    isShowingNoteEditView = false
                                } else {
                                    isEditAlertShown = true
                                }
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("artist.note.save") {
                                settings.artistNotes["\(artist.id)"] = noteText
                                isShowingNoteEditView = false
                            }
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
        .alert("artist.ai.header", isPresented: $isShowingAIInfo) {
            Button("artist.ai.info.ok", role: .cancel) {}
        } message: {
            Text("artist.ai.footer")
        }
    }
}

struct ArtistDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistDetailView(artist: .example, highlightedEventId: nil)
            .environmentObject(DataStore())
            .environmentObject(UserSettings())
    }
}
