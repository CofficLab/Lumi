import Foundation
import Testing
@testable import ProviderStore

/// `StoreEntitlementProviding` 的契约行为。
@Suite("StoreEntitlementProviding")
@MainActor
struct StoreEntitlementProvidingTests {

    /// 只实现 `entitlement` 的最小实现方。
    private final class SnapshotOnlyProvider: StoreEntitlementProviding {
        let entitlement: StoreEntitlementSnapshot

        init(entitlement: StoreEntitlementSnapshot) {
            self.entitlement = entitlement
        }
    }

    /// 档位由权益快照派生：过期即免费档。
    @Test func tierIsDerivedFromSnapshot() {
        let provider = SnapshotOnlyProvider(
            entitlement: StoreEntitlementSnapshot(
                tier: .pro,
                expiresAt: Date().addingTimeInterval(3600)
            )
        )

        #expect(provider.tier == .pro)
    }

    /// 过期权益派生的档位是免费档，而不是「曾经买过」。
    @Test func expiredSnapshotDerivesFreeTier() {
        let provider = SnapshotOnlyProvider(
            entitlement: StoreEntitlementSnapshot(
                tier: .ultimate,
                expiresAt: Date().addingTimeInterval(-3600)
            )
        )

        #expect(provider.tier == .none)
    }

    /// 默认实现不派发任何事件：测试替身与尚未就绪的实现方落到这里。
    @Test func defaultObserverNeverFires() {
        let provider = SnapshotOnlyProvider(entitlement: .none)
        var fired = false

        let handle = provider.addObserver { _ in
            fired = true
        }

        #expect(handle is NoopStoreEntitlementObserverHandle)
        handle.cancel()
        #expect(!fired)
    }

    /// 空句柄可重复取消，不产生副作用。
    @Test func noopHandleCancelIsIdempotent() {
        let handle = NoopStoreEntitlementObserverHandle()
        handle.cancel()
        handle.cancel()
    }

    /// 权益事件只携带变化后的档位。
    @Test func tierChangedEventCarriesNewTier() {
        let event = StoreEntitlementEvent.tierChanged(.ultimate)

        guard case let .tierChanged(tier) = event else {
            Issue.record("事件应当携带变化后的档位")
            return
        }
        #expect(tier == .ultimate)
    }
}
