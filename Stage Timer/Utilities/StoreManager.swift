import StoreKit

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    
    private let productIDs: Set<String> = [
        "com.robinnap.StageTimer.smallcroissant",
        "com.robinnap.StageTimer.twocroissants",
        "com.robinnap.StageTimer.croissantjam",
        "com.robinnap.StageTimer.breakfast"
    ]
    
    private init() {
        Task {
            await loadProducts()
            await listenForTransactions()
        }
    }
    
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
            products.sort { $0.price < $1.price }
        } catch {
            print("Failed to load products:", error)
        }
    }
    
    @MainActor
    func listenForTransactions() async {
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                await handlePurchase(productID: transaction.productID)
                await transaction.finish()
            case .unverified:
                print("Transaction verification failed")
            }
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                await handlePurchase(productID: product.id)
            case .unverified:
                throw StoreError.failedVerification
            }
        case .userCancelled:
            throw StoreError.userCancelled
        case .pending:
            throw StoreError.pending
        @unknown default:
            throw StoreError.unknown
        }
    }
    
    func handlePurchase(productID: String) async {
        purchasedProductIDs.insert(productID)
    }
}

enum StoreError: Error {
    case failedVerification
    case userCancelled
    case pending
    case unknown
} 