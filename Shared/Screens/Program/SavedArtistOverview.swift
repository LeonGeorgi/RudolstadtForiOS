import SwiftUI

//import URLImage

struct SavedArtistOverview: View {
    @State private var showingArtists = true

    var body: some View {
        VStack {
            SavedArtistListView()
        }
        .navigationBarTitle("rated_artists.title", displayMode: .inline)
    }
}

struct SavedArtistOverview_Previews: PreviewProvider {
    static var previews: some View {
        SavedArtistOverview()
                .environmentObject(DataStore())
    }
}
