import StoreKit
import SwiftUI
import WebKit

struct MoreView: View {

    @EnvironmentObject var iapManager: IAPManager

    var body: some View {
        List {
            NavigationLink(value: AppNavigationRoute.about) {
                Label(
                    "about.title",
                    systemImage: "info"
                )
            }

            NavigationLink(value: AppNavigationRoute.parkAndRide) {
                Label(
                    "park_and_ride.title",
                    systemImage: "car"
                )
            }

            NavigationLink(value: AppNavigationRoute.bus) {
                Label(
                    "bus.title",
                    systemImage: "bus"
                )
            }
            NavigationLink(value: AppNavigationRoute.donation) {
                Label(
                    "donations.title",
                    systemImage: "heart"
                )
            }
            NavigationLink(value: AppNavigationRoute.settings) {
                Label(
                    "settings.title",
                    systemImage: "gearshape"
                )
            }

        }
        .navigationBarTitle("more.title")
        .listStyle(.plain)
        .font(.system(size: 18))
    }
}

struct MoreView_Previews: PreviewProvider {
    static var previews: some View {
        MoreView()
    }
}
