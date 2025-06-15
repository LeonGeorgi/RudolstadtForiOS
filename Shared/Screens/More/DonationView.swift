import StoreKit
import SwiftUI

struct DonationView: View {
    @EnvironmentObject var iapManager: IAPManager
    let ticketPrice = 156.0  // Festival ticket price

    var sortedProducts: [SKProduct] {
        iapManager.products.sorted { first, second in
            first.price.doubleValue < second.price.doubleValue
        }
    }

    var body: some View {
        VStack {
            Text("donations.description")
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding()

            Spacer()
            if sortedProducts.isEmpty {
                ProgressView()
                Spacer()
            }
            ForEach(sortedProducts, id: \.productIdentifier) { product in
                DonationButton(product: product, ticketPrice: ticketPrice)
                Spacer()
            }

            Spacer()
            Text("donations.disclaimer")
                .font(.caption)
                .multilineTextAlignment(.leading)
                .padding()
        }
        .onAppear {
            let donationIDs: Set<String> = [
                "donation200",
                "donation500",
                "donation1000",
                "donation2000",
                "donation5000",
            ]
            iapManager.fetchProducts(productIDs: donationIDs)
        }
        .navigationBarTitle("donations.title", displayMode: .inline)
    }
}

struct DonationButton: View {
    @EnvironmentObject var iapManager: IAPManager
    var product: SKProduct
    let ticketPrice: Double

    var body: some View {
        Button(action: {
            iapManager.buyProduct(product)
        }) {
            Text(buttonTitle(for: product))
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 255 / 255, green: 123 / 255, blue: 86 / 255),
                    Color(red: 189 / 255, green: 53 / 255, blue: 1 / 255),
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .foregroundColor(.white)
        // bold text
        .font(.system(size: 16, weight: .semibold))
        .cornerRadius(10)
    }

    func buttonTitle(for product: SKProduct) -> String {
        guard let percentage = formattedPercentage(of: product) else {
            return localizedPrice(product)
        }
        return String(
            format: NSLocalizedString("donation.button.title", comment: ""),
            percentage,
            localizedPrice(product)
        )
    }

    func formattedPercentage(of product: SKProduct) -> String? {
        guard product.priceLocale.currencyCode == "EUR" else { return nil }
        let donationAmount = product.price.doubleValue * 0.7
        let percentage = donationAmount / ticketPrice * 100
        return String(format: "%.0f%%", locale: Locale.current, percentage)
    }

    func localizedPrice(_ product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? "\(product.price)"
    }
}

#Preview {
    DonationView().environmentObject(IAPManager())
}
