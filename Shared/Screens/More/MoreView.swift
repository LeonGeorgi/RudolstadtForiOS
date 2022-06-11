import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink("park_and_ride.title") {
                    ParkAndRideView()
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
