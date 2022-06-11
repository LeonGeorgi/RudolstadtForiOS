import SwiftUI
import WebKit

struct MoreView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink("park_and_ride.title") {
                    ParkAndRideView()
                }
                NavigationLink("bus.title") {
                    BusView()
                }
            }.navigationBarTitle("more.title", displayMode: .inline)
        }
    }
}

struct MoreView_Previews: PreviewProvider {
    static var previews: some View {
        MoreView()
    }
}
