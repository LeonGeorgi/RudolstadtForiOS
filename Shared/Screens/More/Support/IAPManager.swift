import StoreKit

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
            print("received products \(products.map(\.id))")
        } catch {
            print("Failed to fetch products: \(error.localizedDescription)")
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
            print("Product \(productID) not loaded yet")
            return
        }
        buyProduct(product)
    }

    private func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verificationResult):
                let transaction = try verify(verificationResult)
                await transaction.finish()
            case .pending:
                print("Purchase pending for \(product.id)")
            case .userCancelled:
                print("Purchase cancelled for \(product.id)")
            @unknown default:
                print("Unknown purchase result for \(product.id)")
            }
        } catch {
            print("Purchase failed for \(product.id): \(error.localizedDescription)")
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await verificationResult in Transaction.updates {
                do {
                    let transaction = try verify(verificationResult)
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error.localizedDescription)")
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
