import StoreKit
import SwiftUI

struct DonationView: View {
    @EnvironmentObject var iapManager: IAPManager
    @Environment(\.colorScheme) private var colorScheme

    let ticketPrice = 166.00

    var sortedProducts: [SKProduct] {
        iapManager.products.sorted { first, second in
            first.price.doubleValue < second.price.doubleValue
        }
    }

    private var pageBackground: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(.systemBackground),
                    Color.rudolstadt.opacity(0.04),
                    Color(.systemBackground),
                ]
                : [
                    Color(.systemBackground),
                    Color(red: 0.985, green: 0.975, blue: 0.985),
                    Color(.systemBackground),
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard

                if sortedProducts.isEmpty {
                    donationLoadingCard
                } else {
                    donationList
                }

                disclaimerCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(pageBackground.ignoresSafeArea())
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

    private var showsTicketReference: Bool {
        sortedProducts.contains { $0.priceLocale.currencyCode == "EUR" }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("donations.hero.title")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            Text("donations.description")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("donations.hero.note")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if showsTicketReference {
                Text("donations.hero.ticket-note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(colorScheme == .dark ? 0.88 : 0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), lineWidth: 1)
        )
    }

    private var donationLoadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("donations.loading")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var donationList: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ],
            spacing: 12
        ) {
            ForEach(sortedProducts, id: \.productIdentifier) { product in
                DonationButton(product: product, ticketPrice: ticketPrice)
            }
        }
    }

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("donations.disclaimer.title")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)

            Text("donations.disclaimer")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.9))
        )
    }
}

struct DonationButton: View {
    @EnvironmentObject var iapManager: IAPManager
    @Environment(\.colorScheme) private var colorScheme

    var product: SKProduct
    let ticketPrice: Double

    private var tintColor: Color {
        switch product.productIdentifier {
        case "donation200":
            return Color.rudolstadt.opacity(0.82)
        case "donation500":
            return Color(red: 0.17, green: 0.46, blue: 0.74)
        case "donation1000":
            return Color(red: 0.78, green: 0.42, blue: 0.18)
        case "donation2000":
            return Color(red: 0.70, green: 0.22, blue: 0.45)
        default:
            return Color(red: 0.28, green: 0.57, blue: 0.46)
        }
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                tintColor.opacity(colorScheme == .dark ? 0.22 : 0.24),
                tintColor.opacity(colorScheme == .dark ? 0.1 : 0.1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        Button {
            iapManager.buyProduct(product)
        } label: {
            DonationButtonContent(
                localizedPrice: localizedPrice(product),
                secondaryLine: secondaryLine,
                percentage: formattedPercentage(of: product),
                tintColor: tintColor,
                colorScheme: colorScheme
            )
        }
        .buttonStyle(DonationButtonStyle(tintColor: tintColor, colorScheme: colorScheme))
    }

    private var secondaryLine: LocalizedStringKey {
        if let percentage = formattedPercentage(of: product) {
            return LocalizedStringKey(
                String(
                    format: NSLocalizedString("donation.card.caption.ticket", comment: ""),
                    percentage
                )
            )
        } else {
            return "donation.card.caption.generic"
        }
    }

    func formattedPercentage(of product: SKProduct) -> String? {
        guard product.priceLocale.currencyCode == "EUR" else { return nil }
        let donationAmount = product.price.doubleValue * 0.7
        let percentage = donationAmount / ticketPrice * 100
        return String(format: NSLocalizedString("donation.button.percentage", comment: ""), locale: Locale.current, percentage)
    }

    func localizedPrice(_ product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? "\(product.price)"
    }
}

private struct DonationButtonContent: View {
    let localizedPrice: String
    let secondaryLine: LocalizedStringKey
    let percentage: String?
    let tintColor: Color
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(localizedPrice)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tintColor)
            }
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(tintColor.opacity(colorScheme == .dark ? 0.28 : 0.22))
                    .frame(width: 34, height: 34)
                    .blur(radius: 18)
                    .offset(x: -10, y: -16)
            }

            Text(secondaryLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if let percentage {
                Text(percentage)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tintColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(tintColor.opacity(colorScheme == .dark ? 0.16 : 0.14))
                    )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct DonationButtonStyle: ButtonStyle {
    let tintColor: Color
    let colorScheme: ColorScheme

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                tintColor.opacity(colorScheme == .dark ? 0.22 : 0.24),
                tintColor.opacity(colorScheme == .dark ? 0.1 : 0.1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(backgroundGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.06 : 0.2),
                                .clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        tintColor.opacity(configuration.isPressed ? 0.26 : 0.12),
                        lineWidth: configuration.isPressed ? 1.2 : 0.8
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .shadow(
                color: tintColor.opacity(colorScheme == .dark ? 0.1 : 0.08),
                radius: configuration.isPressed ? 8 : 16,
                y: configuration.isPressed ? 4 : 10
            )
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

#Preview {
    DonationView().environmentObject(IAPManager())
}
