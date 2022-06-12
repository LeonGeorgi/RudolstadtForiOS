import SwiftUI
import WebKit

struct MoreView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: GeneralView()) {
                    ProgramEntry(
                        iconName: "music.quarternote.3",
                        label: "general.title"
                    )
                }
            
                NavigationLink(destination: ParkAndRideView()) {
                    ProgramEntry(
                        iconName: "car",
                        label: "park_and_ride.title"
                    )
                }
            
                NavigationLink(destination: BusView()) {
                    ProgramEntry(
                        iconName: "bus",
                        label: "bus.title"
                    )
                }
                NavigationLink(destination: FAQView()) {
                    ProgramEntry(
                        iconName: "questionmark",
                        label: "faq.title"
                    )
                }
                
                NavigationLink(destination: AboutView()) {
                    ProgramEntry(
                        iconName: "info",
                        label: "about.title"
                    )
                }
            }.navigationBarTitle("more.title")
                .listStyle(.plain)
        }
    }
}

struct MoreView_Previews: PreviewProvider {
    static var previews: some View {
        MoreView()
    }
}
