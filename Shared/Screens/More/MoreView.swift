import SwiftUI
import WebKit

struct MoreView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: GeneralView()) {
                    ProgramItemText(title: "general.title")
                }
            
                NavigationLink(destination: ParkAndRideView()) {
                    ProgramItemText(title: "park_and_ride.title")
                }
            
                NavigationLink(destination: BusView()) {
                    ProgramItemText(title: "bus.title")
                }
                NavigationLink(destination: FAQView()) {
                    ProgramItemText(title: "faq.title")
                }
                
                NavigationLink(destination: FAQView()) {
                    ProgramItemText(title: "about.title")
                }
            }.navigationBarTitle("more.title")
        }
    }
}

struct MoreView_Previews: PreviewProvider {
    static var previews: some View {
        MoreView()
    }
}
