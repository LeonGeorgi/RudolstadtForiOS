import StoreKit
import OSLog

@MainActor
final class IAPManager: ObservableObject {
    @Published var products: [Product] = []

    private var transactionUpdatesTask: Task<Void, Never>?

    private enum PurchaseError: LocalizedError {
        case failedVerification
    }

    init() {
        transactionUpdatesTask = observeTransactionUpdates()
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func fetchProducts(productIDs: Set<String>) async {
        do {
            let fetchedProducts = try await Product.products(
                for: Array(productIDs)
            )
            products = fetchedProducts.sorted { first, second in
                first.price < second.price
            }
            AppLog.commerce.info(
                "Loaded StoreKit products: \(self.products.map(\.id).joined(separator: ", "), privacy: .public)"
            )
        } catch {
            AppLog.commerce.error(
                "Failed to fetch StoreKit products: \(error.localizedDescription, privacy: .public)"
            )
            products = []
        }
    }

    func buyProduct(_ product: Product) {
        Task {
            await purchase(product)
        }
    }

    func purchaseProduct(productID: String) {
        guard let product = products.first(where: { $0.id == productID }) else {
            AppLog.commerce.error(
                "Tried to purchase unloaded product \(productID, privacy: .public)"
            )
            return
        }
        buyProduct(product)
    }

    private func purchase(_ product: Product) async {
        do {
            AppLog.commerce.info(
                "Starting purchase flow for \(product.id, privacy: .public)"
            )
            let result = try await product.purchase()
            switch result {
            case .success(let verificationResult):
                let transaction = try verify(verificationResult)
                await transaction.finish()
                AppLog.commerce.info(
                    "Completed purchase for \(product.id, privacy: .public)"
                )
            case .pending:
                AppLog.commerce.info(
                    "Purchase is pending for \(product.id, privacy: .public)"
                )
            case .userCancelled:
                AppLog.commerce.info(
                    "Purchase was cancelled for \(product.id, privacy: .public)"
                )
            @unknown default:
                AppLog.commerce.error(
                    "StoreKit returned an unknown purchase result for \(product.id, privacy: .public)"
                )
            }
        } catch {
            AppLog.commerce.error(
                "Purchase failed for \(product.id, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await verificationResult in Transaction.updates {
                do {
                    let transaction = try verify(verificationResult)
                    await transaction.finish()
                    AppLog.commerce.debug(
                        "Finished StoreKit transaction update \(transaction.id)"
                    )
                } catch {
                    AppLog.commerce.error(
                        "Transaction verification failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
    }

    private func verify<T>(
        _ verificationResult: VerificationResult<T>
    ) throws -> T {
        switch verificationResult {
        case .verified(let signedType):
            return signedType
        case .unverified:
            throw PurchaseError.failedVerification
        }
    }
}
