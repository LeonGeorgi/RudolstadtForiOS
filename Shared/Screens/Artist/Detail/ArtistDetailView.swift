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
                    if artist.url != nil
                        || artist.videoUrl != nil
                        || artist.facebookUrl != nil
                        || artist.instagramUrl != nil
                        || hasArtistLinks
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

            if settings.aiSummaryEnabled && artist.ai?.hasContent == true {
                Section(
                    header: Text("artist.ai.header")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .purple, .blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        ),
                    footer: Text("artist.ai.footer")
                ) {
                    VStack(alignment: .leading, spacing: 5) {
                        if let ai = artist.ai {
                            if let localizedGenres = ai.localizedGenres,
                                !localizedGenres.isEmpty
                            {
                                HStack {
                                    ForEach(localizedGenres, id: \.self) {
                                        genre in
                                        // display as pills
                                        Text(genre)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(
                                                Capsule()
                                                    .fill(
                                                        Color.accentColor
                                                            .opacity(0.2)
                                                    )
                                            )
                                            .foregroundColor(.accentColor)
                                            .padding(1)
                                    }
                                }
                            }
                            if let localizedSummary = ai.localizedSummary,
                                !localizedSummary.isEmpty
                            {
                                Text(localizedSummary)
                                    .font(.body)
                            }

                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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

            if let videoUrl = artist.videoUrl {
                LinkButton(label: "Video", scale: 0.6) {
                    Image("youtube")

                } action: {
                    UIApplication.shared.open(videoUrl)
                }
            }
            if let url = artist.url, let url = URL(string: url) {
                LinkButton(label: "artist.website", scale: 1.0) {
                    Image(systemName: "globe")
                } action: {
                    UIApplication.shared.open(url)
                }
            }
            if let facebookUrl = artist.facebookUrl {
                LinkButton(label: "Facebook", scale: 0.8) {
                    Image("facebook")
                } action: {
                    UIApplication.shared.open(facebookUrl)
                }
            }
            if let instagramUrl = artist.instagramUrl {
                LinkButton(label: "Instagram", scale: 0.8) {
                    Image("instagram")
                } action: {
                    UIApplication.shared.open(instagramUrl)
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

struct GradientBorderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)  // frosted interior
                    .overlay(  // gradient stroke
                        Capsule().strokeBorder(
                            LinearGradient(
                                colors: [.purple, .blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: configuration.isPressed ? 3 : 2
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)  // touch feedback
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
