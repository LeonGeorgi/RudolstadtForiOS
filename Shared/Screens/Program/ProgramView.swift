import SwiftUI

struct ProgramView: View {
    var body: some View {

        NavigationView {
            List {
                NavigationLink(destination: ArtistListView()) {
                    ProgramEntry(
                        iconName: "person.crop.rectangle.stack",
                        label: "artists.title"
                    )
                }
                NavigationLink(destination: SavedArtistOverview()) {
                    ProgramEntry(
                        iconName: "bookmark",
                        label: "rated_artists.title"
                    )
                }
                NavigationLink(destination: TimeProgramView()) {
                    ProgramEntry(
                        iconName: "clock",
                        label: "program_by_time.title"
                    )
                }
                NavigationLink(destination: StageProgramView()) {
                    ProgramEntry(
                        iconName: "music.mic",
                        label: "program_by_stage.title"
                    )
                }

            }.listStyle(.plain)
                .navigationBarTitle("program.title")
        }
    }
}

struct ProgramView_Previews: PreviewProvider {
    static var previews: some View {
        ProgramView()
    }
}
