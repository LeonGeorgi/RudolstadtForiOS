import SwiftUI

struct ProgramView: View {
    var body: some View {

        NavigationView {
            List {
                NavigationLink(destination: ArtistListView()) {
                    ProgramItemText(title: "artists.title")
                }
                NavigationLink(destination: SavedArtistOverview()) {
                    ProgramItemText(title: "rated_artists.title")
                }
                NavigationLink(destination: TimeProgramView()) {
                    ProgramItemText(title: "program_by_time.title")
                }
                NavigationLink(destination: StageProgramView()) {
                    ProgramItemText(title: "program_by_stage.title")
                }

                NavigationLink(destination: LocationListView()) {
                    ProgramItemText(title: "locations.title")
                }

            }.navigationBarTitle("program.title")
        }
    }
}

struct ProgramView_Previews: PreviewProvider {
    static var previews: some View {
        ProgramView()
    }
}