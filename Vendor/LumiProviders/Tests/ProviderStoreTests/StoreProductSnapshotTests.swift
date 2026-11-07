import Foundation
import Testing
@testable import ProviderStore

/// `StoreProductSnapshot` 与 `StoreProductCatalog` 的契约行为。
@Suite("StoreProductSnapshot")
struct StoreProductSnapshotTests {

    /// 订阅类商品的判定。
    @Test func subscriptionKindDetection() {
        #expect(StoreProductKind.autoRenewable.isSubscription)
        #expect(StoreProductKind.nonRenewable.isSubscription)
        #expect(!StoreProductKind.consumable.isSubscription)
        #expect(!StoreProductKind.nonConsumable.isSubscription)
        #expect(!StoreProductKind.unknown.isSubscription)
    }

    /// 快照保留展示所需的全部字段。
    @Test func snapshotKeepsDisplayFields() {
        let snapshot = StoreProductSnapshot(
            id: "com.example.pro.monthly",
            displayName: "Pro Monthly",
            price: "¥68.00",
            kind: .autoRenewable,
            tier: .pro,
            productDescription: "Pro subscription"
        )

        #expect(snapshot.id == "com.example.pro.monthly")
        #expect(snapshot.displayName == "Pro Monthly")
        #expect(snapshot.price == "¥68.00")
        #expect(snapshot.isSubscription)
        #expect(snapshot.grantsEntitlement)
    }

    /// 不授予档位的商品不带来权益：占位商品不该出现在付费列表里。
    @Test func placeholderProductGrantsNoEntitlement() {
        let snapshot = StoreProductSnapshot(
            id: "consumable.fuel.octane87",
            displayName: "Fuel",
            price: "¥6.00",
            kind: .consumable,
            tier: .none
        )

        #expect(!snapshot.grantsEntitlement)
    }

    /// 快照可编解码。
    @Test func snapshotRoundTripsThroughCodable() throws {
        let snapshot = StoreProductSnapshot(
            id: "com.example.pro.yearly",
            displayName: "Pro Yearly",
            price: "¥488.00",
            kind: .autoRenewable,
            tier: .pro
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(StoreProductSnapshot.self, from: data)

        #expect(decoded == snapshot)
    }
}

/// `StoreProductCatalog` 的映射语义。
@Suite("StoreProductCatalog")
struct StoreProductCatalogTests {

    /// 测试用商品表。
    private struct TestCatalog: StoreProductCatalog {
        let productTiers: [String: StoreTier] = [
            "com.example.pro.monthly": .pro,
            "com.example.pro.yearly": .pro,
            "com.example.ultimate.yearly": .ultimate,
            "com.example.placeholder": .none,
        ]
    }

    /// 档位映射按商品 ID 查询。
    @Test func tierLookupByProductId() {
        let catalog = TestCatalog()

        #expect(catalog.tier(for: "com.example.pro.monthly") == .pro)
        #expect(catalog.tier(for: "com.example.ultimate.yearly") == .ultimate)
    }

    /// 未登记的商品不授予权益：默认拒绝，而非默认放行。
    ///
    /// 这是「买了不给权益」链路的直接守卫：没有映射的商品不能影响权益判定。
    @Test func unknownProductGrantsNoTier() {
        #expect(TestCatalog().tier(for: "com.example.unknown") == .none)
    }

    /// 全部商品 ID 可枚举。
    @Test func allProductIdsAreEnumerable() {
        let ids = TestCatalog().allProductIds

        #expect(ids.count == 4)
        #expect(ids.contains("com.example.pro.monthly"))
    }

    /// 付费商品列表排除占位商品。
    @Test func subscriptionProductIdsExcludePlaceholders() {
        let ids = Set(TestCatalog().subscriptionProductIds)

        #expect(ids.contains("com.example.pro.monthly"))
        #expect(ids.contains("com.example.ultimate.yearly"))
        #expect(!ids.contains("com.example.placeholder"))
    }

    /// 内存态商品表与协议默认值一致。
    @Test func staticCatalogMatchesProtocolDefaults() {
        let catalog = StaticStoreProductCatalog([
            "com.example.pro.monthly": .pro,
            "com.example.placeholder": .none,
        ])

        #expect(catalog.tier(for: "com.example.pro.monthly") == .pro)
        #expect(catalog.tier(for: "com.example.placeholder") == .none)
        #expect(catalog.subscriptionProductIds == ["com.example.pro.monthly"])
    }
}
