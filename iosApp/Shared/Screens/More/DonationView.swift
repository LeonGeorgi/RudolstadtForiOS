import StoreKit
import SwiftUI

struct DonationView: View {
    @EnvironmentObject var iapManager: IAPManager

    private let donationIDs: Set<String> = [
        "donation200",
        "donation500",
        "donation1000",
        "donation2000",
        "donation5000",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("donations.hero.title")
                        .font(.title2.bold())
                    Text("donations.description")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

                if iapManager.products.isEmpty {
                    ProgressView("donations.loading")
                        .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(iapManager.products, id: \.id) { product in
                            DonationRow(product: product)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("donations.hero.note")
                    Text("donations.disclaimer")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .font(.body)
        .navigationTitle("donations.title")
        .task {
            await iapManager.fetchProducts(productIDs: donationIDs)
        }
    }
}

private struct DonationRow: View {
    @EnvironmentObject var iapManager: IAPManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let product: Product

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading) {
                Text(title)
                purchaseButton
            }
        } else {
            HStack {
                Text(title)
                Spacer()
                purchaseButton
            }
        }
    }

    private var purchaseButton: some View {
        Button {
            iapManager.buyProduct(product)
        } label: {
            ZStack {
                // Der breiteste lokalisierte Preis bestimmt alle Buttonbreiten.
                ForEach(iapManager.products, id: \.id) { product in
                    Text(product.displayPrice).hidden()
                }
                Text(product.displayPrice)
            }
            .fontWeight(.semibold)
            .fixedSize()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel(Text(title))
        .accessibilityValue(product.displayPrice)
    }

    private var title: LocalizedStringKey {
        switch product.id {
        case "donation200":
            return "donation.card.caption.200"
        case "donation500":
            return "donation.card.caption.500"
        case "donation1000":
            return "donation.card.caption.1000"
        case "donation2000":
            return "donation.card.caption.2000"
        case "donation5000":
            return "donation.card.caption.5000"
        default:
            return "donation.card.caption.default"
        }
    }
}

#Preview {
    DonationView().environmentObject(IAPManager())
}
