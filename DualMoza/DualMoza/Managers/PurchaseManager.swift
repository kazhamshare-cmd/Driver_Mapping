import StoreKit
import SwiftUI

@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    @Published var isPro: Bool = false
    @Published var isLoading: Bool = false
    @Published var proProduct: Product? = nil
    @Published var proPriceString: String = ""  // ローカライズされた価格文字列

    private let proProductId = "com.dualmoza.pro"
    private var updateListenerTask: Task<Void, Error>? = nil

    init() {
        // UserDefaultsから購入状態を復元（実際はレシート検証が必要）
        isPro = UserDefaults.standard.bool(forKey: "isPro")

        // トランザクション監視開始
        updateListenerTask = listenForTransactions()

        // 購入状態を確認 & 商品情報を取得
        Task {
            await updatePurchasedProducts()
            await loadProducts()
        }
    }

    // MARK: - Load Products
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [proProductId])
            if let product = products.first {
                proProduct = product
                proPriceString = product.displayPrice  // ローカライズされた価格（例：¥1,900、$12.99）
            }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }

    // MARK: - Verify Transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Update Purchased Products
    func updatePurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == proProductId {
                    await MainActor.run {
                        self.isPro = true
                        UserDefaults.standard.set(true, forKey: "isPro")
                    }
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }
    }

    // MARK: - Purchase Pro
    func purchasePro() async throws {
        isLoading = true
        defer { isLoading = false }

        let products = try await Product.products(for: [proProductId])
        guard let product = products.first else {
            throw StoreError.productNotFound
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
        case .userCancelled:
            throw StoreError.userCancelled
        case .pending:
            throw StoreError.pending
        @unknown default:
            throw StoreError.unknown
        }
    }

    // MARK: - Restore Purchases
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }
}

// MARK: - Store Errors
enum StoreError: Error, LocalizedError {
    case failedVerification
    case productNotFound
    case userCancelled
    case pending
    case unknown

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "購入の検証に失敗しました"
        case .productNotFound:
            return "商品が見つかりません"
        case .userCancelled:
            return "購入がキャンセルされました"
        case .pending:
            return "購入は保留中です"
        case .unknown:
            return "不明なエラーが発生しました"
        }
    }
}
