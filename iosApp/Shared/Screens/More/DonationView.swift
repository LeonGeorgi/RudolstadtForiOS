import StoreKit
import SwiftUI

struct DonationView: View {
    @EnvironmentObject var iapManager: IAPManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var heartSize: CGFloat = 30
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 48
    @State private var selectedProductID = "donation1000"

    private let donationIDs: Set<String> = [
        "donation200",
        "donation500",
        "donation1000",
        "donation2000",
        "donation5000",
    ]

    private var selectedProduct: Product? {
        iapManager.products.first { $0.id == selectedProductID }
            ?? iapManager.products.first
    }

    var body: some View {
        let selection = selectedProduct

        Form {
            Section {
                if let selection {
                    ForEach(iapManager.products, id: \.id) { product in
                        let isSelected = product.id == selection.id

                        Button {
                            selectedProductID = product.id
                        } label: {
                            DonationOptionLabel(product: product, isSelected: isSelected)
                        }
                        .listRowBackground(
                            isSelected
                                ? Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.12)
                                : nil
                        )
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                } else {
                    ProgressView("donations.loading")
                        .frame(maxWidth: .infinity)
                }
            } header: {
                VStack(spacing: 24) {
                    introduction

                    if let selection {
                        selectedAmount(for: selection)
                    }
                }
                .font(.body)
                .textCase(nil)
                .padding(.bottom, 16)
            } footer: {
                VStack(alignment: .leading, spacing: 16) {
                    if let selection {
                        purchaseButton(for: selection)
                            .padding(.top, 16)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("donations.hero.note")
                        Text("donations.disclaimer")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("donations.title")
        .task {
            await iapManager.fetchProducts(productIDs: donationIDs)
        }
    }

    @ViewBuilder
    private var introduction: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 16) {
                introductionContent
            }
        } else {
            HStack(spacing: 20) {
                introductionContent
            }
        }
    }

    private var introductionContent: some View {
        Group {
            Image(systemName: "heart")
                .font(.system(size: heartSize))
                .foregroundStyle(.tint)
                .frame(width: heartSize * 1.2)
                .accessibilityHidden(true)

            Text("donations.description")
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func selectedAmount(for product: Product) -> some View {
        Text(product.displayPrice)
            .font(.system(size: amountSize, weight: .semibold))
            .foregroundStyle(.tint)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text("donations.selected_amount"))
            .accessibilityValue(product.displayPrice)
    }

    @ViewBuilder
    private func purchaseButton(for product: Product) -> some View {
        let button = Button {
            iapManager.buyProduct(product)
        } label: {
            Text("donations.button.donate \(product.displayPrice)")
                .font(.body)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .tint(Color.accentColor)

        if #available(iOS 26.0, macOS 26.0, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.borderedProminent)
        }
    }
}

private struct DonationOptionLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let product: Product
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: "checkmark")
                .foregroundStyle(.tint)
                .opacity(isSelected ? 1 : 0)
                .accessibilityHidden(true)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    caption
                    price
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    caption
                        .frame(maxWidth: .infinity, alignment: .leading)
                    price.fixedSize()
                }
            }
        }
        .foregroundStyle(Color.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(product.displayPrice)
    }

    private var caption: some View {
        Text(title)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var price: some View {
        Text(product.displayPrice)
            .foregroundStyle(Color.secondary)
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
