import StoreKit
import SwiftUI
import WebKit

struct MoreView: View {

    @EnvironmentObject var iapManager: IAPManager

    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: GeneralView()) {
                    Label(
                        "general.title",
                        systemImage: "music.quarternote.3"
                    )
                }

                NavigationLink(destination: ParkAndRideView()) {
                    Label(
                        "park_and_ride.title",
                        systemImage: "car"
                    )
                }

                NavigationLink(destination: BusView()) {
                    Label(
                        "bus.title",
                        systemImage: "bus"
                    )
                }
                NavigationLink(destination: AboutView()) {
                    Label(
                        "about.title",
                        systemImage: "info"
                    )
                }
                NavigationLink {
                    DonationView()
                } label: {
                    Label(
                        "donations.title",
                        systemImage: "heart"
                    )
                }
                NavigationLink {
                    SettingsView()
                } label: {
                    Label(
                        "settings.title",
                        systemImage: "gearshape"
                    )
                }

            }.navigationBarTitle("more.title")
                .listStyle(.plain)
        }
        .font(.system(size: 18))
    }
}

struct MoreView_Previews: PreviewProvider {
    static var previews: some View {
        MoreView()
    }
}
