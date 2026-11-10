import Foundation
import Testing
@testable import ProviderStore

/// `StoreEntitlementSnapshot` 的过期判定与生效档位。
///
/// 这些判定是付费链路的闸门：「过期即免费」写错一次，就意味着
/// 免费用户能用付费功能，或付费用户被误判为免费。
@Suite("StoreEntitlementSnapshot")
struct StoreEntitlementSnapshotTests {

    /// 有效订阅保留 Pro 档位。
    @Test func activeSubscriptionKeepsProTier() {
        let snapshot = StoreEntitlementSnapshot(
            tier: .pro,
            expiresAt: Date().addingTimeInterval(3600)
        )

        #expect(!snapshot.isExpired)
        #expect(snapshot.isProOrHigher)
        #expect(snapshot.effectiveTier == .pro)
    }

    /// 过期订阅等价于免费档——不是「曾经买过」。
    @Test func expiredSubscriptionIsTreatedAsFree() {
        let snapshot = StoreEntitlementSnapshot(
            tier: .pro,
            expiresAt: Date().addingTimeInterval(-3600)
        )

        #expect(snapshot.isExpired)
        #expect(!snapshot.isProOrHigher)
        #expect(snapshot.effectiveTier == .none)
    }

    /// 没有到期时间视为已过期：有效期不明的权益不能当作有效。
    @Test func missingExpirationIsTreatedAsExpired() {
        let snapshot = StoreEntitlementSnapshot(tier: .pro, expiresAt: nil)

        #expect(snapshot.isExpired)
        #expect(snapshot.effectiveTier == .none)
    }

    /// 到期时刻不足 60 秒仍在宽限期内，避免续费瞬间误判为过期。
    @Test func gracePeriodKeepsSubscriptionValid() {
        let snapshot = StoreEntitlementSnapshot(
            tier: .pro,
            expiresAt: Date().addingTimeInterval(30)
        )

        #expect(!snapshot.isExpired)
        #expect(snapshot.isProOrHigher)
    }

    /// 超过宽限期的到期时刻判定为过期。
    @Test func beyondGracePeriodIsExpired() {
        let snapshot = StoreEntitlementSnapshot(
            tier: .pro,
            expiresAt: Date().addingTimeInterval(-120)
        )

        #expect(snapshot.isExpired)
    }

    /// 免费档无论是否有过期时间都不算付费权益。
    @Test func freeTierNeverGrantsPro() {
        let snapshot = StoreEntitlementSnapshot(
            tier: .none,
            expiresAt: Date().addingTimeInterval(3600)
        )

        #expect(!snapshot.isProOrHigher)
        #expect(snapshot.effectiveTier == .none)
    }

    /// 旗舰档过期后同样回落到免费档。
    @Test func expiredUltimateTierFallsBackToFree() {
        let snapshot = StoreEntitlementSnapshot(
            tier: .ultimate,
            expiresAt: Date().addingTimeInterval(-3600)
        )

        #expect(snapshot.isExpired)
        #expect(snapshot.effectiveTier == .none)
    }

    /// 空权益是免费档且已过期。
    @Test func noneSnapshotIsFreeAndExpired() {
        #expect(StoreEntitlementSnapshot.none.tier == .none)
        #expect(StoreEntitlementSnapshot.none.isExpired)
        #expect(StoreEntitlementSnapshot.none.effectiveTier == .none)
    }

    /// 快照可编解码，用于本地缓存。
    @Test func snapshotRoundTripsThroughCodable() throws {
        let snapshot = StoreEntitlementSnapshot(
            tier: .ultimate,
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(StoreEntitlementSnapshot.self, from: data)

        #expect(decoded == snapshot)
        #expect(decoded.tier == .ultimate)
    }
}
