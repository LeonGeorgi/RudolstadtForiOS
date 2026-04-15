import MusicKit
import SwiftUI

struct ArtistDetailView: View {
    let artist: Artist
    let highlightedEventId: Int?

    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var dataStore: DataStore

    @State private var isShowingNoteEditView = false
    @State var isEditAlertShown: Bool = false
    @State var noteText: String = ""

    @Namespace private var imageViewerTransition

    @State private var artistBackgroundColor: Color
    @State private var descriptionBackgroundColor: Color
    @State private var descriptionBackgroundStartY = CGFloat.infinity
    @State private var artistColorScheme: ColorScheme?

    init(artist: Artist, highlightedEventId: Int?) {
        self.artist = artist
        self.highlightedEventId = highlightedEventId
        _artistBackgroundColor = State(
            initialValue: ArtistImageColorCache.shared.cachedBackgroundColor(
                for: artist.id
            ) ?? .clear
        )
        _descriptionBackgroundColor = State(
            initialValue: ArtistImageColorCache.shared.cachedDescriptionBackgroundColor(
                for: artist.id
            ) ?? .clear
        )
        _artistColorScheme = State(
            initialValue: ArtistImageColorCache.shared.cachedPreferredColorScheme(
                for: artist.id
            )
        )
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

    private func loadArtistBackgroundColor() async {
        guard let backgroundColor = await ArtistImageColorCache.shared.backgroundColor(for: artist) else {
            return
        }

        let descriptionColor = ArtistImageColorCache.shared.cachedDescriptionBackgroundColor(
            for: artist.id
        )
        let colorScheme = ArtistImageColorCache.shared.cachedPreferredColorScheme(
            for: artist.id
        )

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.35)) {
                artistBackgroundColor = backgroundColor
                descriptionBackgroundColor = descriptionColor ?? .clear
                artistColorScheme = colorScheme
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

                        ArtistAISummaryBlock(artist: artist)
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
                }
            }
        }
        .onPreferenceChange(DescriptionBackgroundStartPreferenceKey.self) { startY in
            descriptionBackgroundStartY = startY
        }
        .environment(\.colorScheme, artistColorScheme ?? .light)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(artistColorScheme, for: .navigationBar)
        .task(id: artist.id) {
            await loadArtistBackgroundColor()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if artist.ai?.hasContent == true {
                        Button(action: {
                            settings.aiSummaryEnabled.toggle()
                        }) {
                            Image(systemName: "sparkles")
                        }
                    }

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
    }
}

struct ArtistDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistDetailView(artist: .example, highlightedEventId: nil)
            .environmentObject(DataStore())
            .environmentObject(UserSettings())
    }
}
