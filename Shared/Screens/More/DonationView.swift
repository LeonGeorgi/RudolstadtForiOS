import SwiftUI
import StoreKit

struct DonationView: View {
    @EnvironmentObject var iapManager: IAPManager
    let ticketPrice = 156.0 // Festival ticket price
    
    var body: some View {
        VStack(spacing: 20) {
            Text("donations.description")
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding()
            
            Spacer()
            
            ForEach(iapManager.products, id: \.productIdentifier) { product in
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
                "donation5000"
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
        .background(Color.accentColor)
        .foregroundColor(.white)
        .cornerRadius(10)
    }
    
    func buttonTitle(for product: SKProduct) -> String {
        guard let percentage = formattedPercentage(of: product) else {
            return localizedPrice(product)
        }
        return String(format: NSLocalizedString("donation.button.title", comment: ""), percentage, localizedPrice(product))
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
