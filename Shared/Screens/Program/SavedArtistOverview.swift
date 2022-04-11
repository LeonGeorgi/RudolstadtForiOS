import SwiftUI

//import URLImage

struct SavedArtistOverview: View {
    @State private var showingArtists = true

    var body: some View {
        VStack {
            if showingArtists {
                SavedArtistListView()
            } else {
                SavedArtistProgramView()
            }
        }
                .navigationBarTitle("rated_artists.title", displayMode: .inline)
                .navigationBarItems(trailing: Button(action: {
                    self.showingArtists.toggle()
                }) {
                    if showingArtists {
                        Text("Konzerte") // TODO
                    } else {
                        Text("Künstler") // TODO
                    }
                })
    }
}

struct SavedArtistOverview_Previews: PreviewProvider {
    static var previews: some View {
        SavedArtistOverview()
                .environmentObject(DataStore())
    }
}
