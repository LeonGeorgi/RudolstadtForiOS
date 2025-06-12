import StoreKit

class IAPManager: NSObject, ObservableObject, SKProductsRequestDelegate,
    SKPaymentTransactionObserver
{
    @Published var products: [SKProduct] = []
    var productsRequest: SKProductsRequest?

    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }

    func fetchProducts(productIDs: Set<String>) {
        print("fetching products")
        let request = SKProductsRequest(productIdentifiers: productIDs)
        self.productsRequest = request
        request.delegate = self
        request.start()
    }

    func productsRequest(
        _ request: SKProductsRequest,
        didReceive response: SKProductsResponse
    ) {
        print("received products \(response.products)")
        DispatchQueue.main.async {
            self.products = response.products
        }
    }

    func buyProduct(_ product: SKProduct) {
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    func purchaseProduct(productID: String) {
        let paymentRequest = SKMutablePayment()
        paymentRequest.productIdentifier = productID
        SKPaymentQueue.default().add(paymentRequest)
    }

    func paymentQueue(
        _ queue: SKPaymentQueue,
        updatedTransactions transactions: [SKPaymentTransaction]
    ) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased, .restored:
                SKPaymentQueue.default().finishTransaction(transaction)
            case .failed:
                SKPaymentQueue.default().finishTransaction(transaction)
            default:
                break
            }
        }
    }

    deinit {
        SKPaymentQueue.default().remove(self)
    }
}
