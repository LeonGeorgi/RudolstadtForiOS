import ImageViewer
import ImageViewerRemote
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

    @State private var isDisplayingImageViewer = false
    @State var imageURL = ""

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

    var artistLinks: ArtistLinks? {
        if let artistLinks = dataStore.artistLinks {
            return artistLinks[artist.name]
        }
        return nil
    }

    var hasArtistLinks: Bool {
        guard let artistLinks = artistLinks else { return false }
        return artistLinks.hasLinks
    }

    var body: some View {
        List {
            Section(
                footer: artist.countries.isEmpty
                    ? Text(artist.formattedName)
                    : Text("\(artist.formattedName) (\(artist.countries))")
            ) {
                ZStack {
                    VStack(spacing: 0) {
                        ArtistImageView(artist: artist, fullImage: true)
                            .frame(maxHeight: 500)
                            .clipped()
                            .onTapGesture {
                                imageURL = artist.fullImageUrl!.absoluteString
                                isDisplayingImageViewer.toggle()
                            }
                    }
                    if artist.url != nil || artist.youtubeID != nil
                        || artist.facebookID != nil || hasArtistLinks
                    {
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                                .frame(height: 100)
                                .mask {
                                    VStack(spacing: 0) {
                                        LinearGradient(
                                            stops: [
                                                .init(
                                                    color: .black.opacity(0),
                                                    location: 0
                                                ),
                                                .init(
                                                    color: .black.opacity(1),
                                                    location: 0.4
                                                ),
                                                .init(
                                                    color: .black.opacity(1),
                                                    location: 1
                                                ),
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        .frame(height: 100)

                                        Rectangle()
                                    }
                                }
                        }
                        VStack {
                            Spacer()
                            renderLinks()
                        }.padding()
                    }
                }.listRowInsets(EdgeInsets())
            }

            Section(footer: Text("artist.rating.explanation.content")) {
                ArtistRatingView(artist: artist)
            }

            if let artistNote = artistNote {
                if artistNote != "" {
                    Section("artist.notes.headline") {
                        HStack(alignment: .firstTextBaseline) {
                            Text(artistNote)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Button {
                                isShowingNoteEditView = true
                            } label: {
                                Image(systemName: "square.and.pencil")
                            }

                        }
                    }
                }
            }

            switch artistEvents {
            case .loading:
                Text("events.loading")
            case .failure(let reason):
                Text("Failed to load: " + reason.rawValue)
            case .success(let events):
                if !events.isEmpty {
                    Section(header: Text("artist.events")) {
                        ForEach(events) { (event: Event) in
                            NavigationLink(
                                destination: StageDetailView(
                                    stage: event.stage,
                                    highlightedEventId: event.id
                                )
                            ) {
                                ArtistEventCell(event: event)
                            }.listRowBackground(
                                highlightedEventId == event.id
                                    && events.count > 1
                                    ? Color.yellow.opacity(0.3) : nil
                            )
                        }
                    }
                }
            }

            if artist.formattedDescription != nil
                && artist.formattedDescription != ""
            {
                Section(header: Text("artist.description")) {
                    Text(artist.formattedDescription!)
                }
            }

        }.listStyle(GroupedListStyle())
            .navigationBarTitle(Text(artist.formattedName), displayMode: .large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(
                        artistNote ?? "" == ""
                            ? "artist.add-note.button"
                            : "artist.edit-note.button"
                    ) {
                        isShowingNoteEditView.toggle()
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
                                    settings.artistNotes["\(artist.id)"] =
                                        noteText
                                    isShowingNoteEditView = false
                                }
                            }
                        }.alert(isPresented: $isEditAlertShown) {
                            Alert(
                                title: Text("artist.note.cancel.alert.title"),
                                message: Text(
                                    "artist.note.cancel.alert.message"
                                ),
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
                }.interactiveDismissDisabled()
            }
            .fullScreenCover(isPresented: $isDisplayingImageViewer) {
                ImageViewerRemote(
                    imageURL: $imageURL,
                    viewerShown: $isDisplayingImageViewer
                )
            }
    }

    private func renderLinks() -> some View {
        HStack {

            if let youtubeID = artist.youtubeID,
                let url = URL(
                    string: "https://www.youtube.com/watch?v=\(youtubeID)"
                )
            {
                LinkButton(label: "YouTube", scale: 0.6) {
                    Image("youtube")
                } action: {
                    UIApplication.shared.open(url)
                }
            }
            if let url = artist.url, let url = URL(string: url) {
                LinkButton(label: "artist.website", scale: 1.0) {
                    Image(systemName: "globe")
                } action: {
                    UIApplication.shared.open(url)
                }
            }
            if let facebookID = artist.facebookID,
                let url = URL(string: "fb://profile/\(facebookID)")
            {
                LinkButton(label: "Facebook", scale: 0.8) {
                    Image("facebook")
                } action: {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else if let url = URL(
                        string: "https://www.facebook.com/\(facebookID)"
                    ) {
                        UIApplication.shared.open(url)
                    }

                }
            }
            if let artistLinks = dataStore.artistLinks,
                let artistLink = artistLinks[artist.name],
                let appleMusicURL = artistLink.appleMusicURL
            {
                LinkButton(label: "Apple Music", scale: 1.0) {
                    Image(systemName: "music.note")
                } action: {
                    UIApplication.shared.open(URL(string: appleMusicURL)!)
                }
            }

            if let artistLinks = dataStore.artistLinks,
                let artistLink = artistLinks[artist.name],
                let spotifyURL = artistLink.spotifyURL
            {
                LinkButton(label: "Spotify", scale: 0.7) {
                    Image("spotify")
                } action: {
                    UIApplication.shared.open(URL(string: spotifyURL)!)
                }
            }
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

struct LinkButton: View {
    let label: LocalizedStringKey
    let scale: CGFloat
    let icon: () -> Image
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                icon()
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .scaleEffect(scale)
                Text(label)
                    .font(.caption)
                    .scaledToFit()
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }.buttonStyle(BorderlessButtonStyle())
            .padding(10)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .foregroundColor(.primary)
            .environment(\.colorScheme, .dark)
    }
}
