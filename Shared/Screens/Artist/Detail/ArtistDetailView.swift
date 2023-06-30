//
//  ArtistDetailView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 25.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ArtistDetailView: View {
    let artist: Artist
    
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var dataStore: DataStore
    
    @State private var isShowingNoteEditView = false
    @State var isEditAlertShown: Bool = false
    @State var noteText: String = ""
    
    
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
    
    func rateArtist(rating: Int) {
        print(settings.ratings)
        var ratings = settings.ratings
        ratings["\(artist.id)"] = rating
        print(ratings)
        settings.ratings = ratings
        
    }
    
    func artistRating() -> Int {
        settings.ratings["\(artist.id)"] ?? 0
    }
    
    var body: some View {
        List {
            Section(footer: artist.countries.isEmpty ? Text(artist.name) : Text("\(artist.name) (\(artist.countries))")) {
                ArtistImageView(artist: artist, fullImage: true).listRowInsets(EdgeInsets())
                    .frame(maxHeight: 500)
                    .clipped()
            }
            
            renderRating()
            
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
                            NavigationLink(destination: StageDetailView(stage: event.stage)) {
                                ArtistEventCell(event: event)
                            }
                        }
                    }
                }
            }
            
            if artist.formattedDescription != nil && artist.formattedDescription != "" {
                Section(header: Text("artist.description")) {
                    Text(artist.formattedDescription!)
                }
            }
            
            if artist.url != nil || artist.youtubeID != nil || artist.facebookID != nil {
                renderLinks()
            }
            
        }.listStyle(GroupedListStyle())
            .navigationBarTitle(Text(artist.name), displayMode: .large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(artistNote ?? "" == "" ? "artist.add-note.button" : "artist.edit-note.button") {
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
                                settings.artistNotes["\(artist.id)"] = noteText
                                isShowingNoteEditView = false
                            }
                        }
                    }.alert(isPresented: $isEditAlertShown) {
                        Alert(
                            title: Text("artist.note.cancel.alert.title"),
                            message: Text("artist.note.cancel.alert.message"),
                            primaryButton: .destructive(Text("artist.note.cancel.alert.yes")) {
                                isEditAlertShown = false
                                noteText = artistNote ?? ""
                                isShowingNoteEditView = false
                            }, secondaryButton: .cancel(Text("artist.note.cancel.alert.no")) {
                                isEditAlertShown = false
                            })
                    }
                }.interactiveDismissDisabled()
            }
            .onAppear {
                noteText = artistNote ?? ""
            }
    }
    
    func saveNote() {
    }
    
    private func renderRating() -> some View {
        Section(footer: Text("artist.rating.explanation.content")) {
            HStack {
                Spacer()
                ForEach(-1..<4) { rating in
                    Text(getSymbolForRating(rating))
                        .font(.system(size: 35))
                    //.grayscale(1.0)
                        .saturation(getSaturationForRating(rating))
                        .onTapGesture {
                            if artistRating() != rating {
                                self.rateArtist(rating: rating)
                            }
                        }
                    if rating < 1 {
                        Divider()
                            .padding(.vertical, 5)
                            .padding(.horizontal, 0)
                    }
                    
                }
                Spacer()
            }
        }
    }
    
    private func getSymbolForRating(_ rating: Int) -> String {
        switch rating {
        case -1: return "🥱"
        case 0: return "🤔"
        case 1: return "❤️"
        case 2: return "❤️"
        case 3: return "❤️"
        default: return "Invalid"
        }
    }
    
    private func getSaturationForRating(_ symbolValue: Int) -> Double {
        let r = artistRating()
        if r == symbolValue {
            return 1.0
        }
        if (symbolValue > 0 && symbolValue < r) {
            return 1.0
        }
        return 0.0
    }
    
    private func renderLinks() -> some View {
        Section(header: Text("artist.links")) {
            if artist.url != nil {
                Button(action: {
                    guard let url = URL(string: artist.url!) else {
                        return
                    }
                    UIApplication.shared.open(url)
                }) {
                    Text("artist.website")
                }
            }
            if artist.youtubeID != nil {
                Button(action: {
                    guard let url = URL(string: "https://www.youtube.com/watch?v=\(artist.youtubeID!)") else {
                        return
                    }
                    UIApplication.shared.open(url)
                    
                    
                }) {
                    Text("YouTube")
                }
            }
            if artist.facebookID != nil {
                Button(action: {
                    guard let url = URL(string: "fb://profile/\(artist.facebookID!)") else {
                        return
                    }
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        guard let url = URL(string: "https://www.facebook.com/\(artist.facebookID!)") else {
                            return
                        }
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Facebook")
                }
            }
        }
    }
}

struct ArtistDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistDetailView(artist: .example)
            .environmentObject(DataStore())
            .environmentObject(UserSettings())
    }
}
