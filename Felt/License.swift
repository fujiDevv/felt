import StoreKit
import Combine

@MainActor
final class FeltLicense: ObservableObject {
    // Set up this non-consumable with the same ID in App Store Connect before release.
    static let productID = "com.fujidevv.Felt.allWorlds"
    @Published private(set) var purchased = false
    @Published private(set) var product: Product?
    @Published private(set) var busy = false
    @Published var message: String?
    private var updates: Task<Void, Never>?

    var unlocked: Bool {
        #if DEBUG
        return true
        #else
        return purchased
        #endif
    }
    var price: String { product?.displayPrice ?? "$4.99" }
    var edition: String {
        #if DEBUG
        "Development edition · All worlds unlocked"
        #else
        purchased ? "All worlds unlocked" : "Paper + pinch are free"
        #endif
    }

    func start() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                if case .verified(let transaction) = result, transaction.productID == Self.productID {
                    await self?.refresh()
                    await transaction.finish()
                }
            }
        }
        Task { await refresh(); await loadProduct() }
    }
    func stop() { updates?.cancel(); updates = nil }
    func refresh() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID, transaction.revocationDate == nil {
                entitled = true
            }
        }
        purchased = entitled
    }
    private func loadProduct() async {
        do { product = try await Product.products(for: [Self.productID]).first }
        catch { message = "The App Store is unavailable. Paper + pinch still work." }
    }
    func purchase() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        if product == nil { await loadProduct() }
        guard let product else { message = "Purchases become available when Felt is listed on the App Store."; return }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await refresh(); await transaction.finish(); message = "All worlds are yours."
            case .success(.unverified): message = "Unable to verify the purchase. Try restoring purchases."
            case .pending: message = "Your purchase is awaiting approval."
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = "Purchase failed. Please try again." }
    }
    func restore() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do { try await AppStore.sync(); await refresh(); message = purchased ? "Purchase restored." : "No purchase found. Paper + pinch still work." }
        catch { message = "Restore failed. Please try again." }
    }
}
