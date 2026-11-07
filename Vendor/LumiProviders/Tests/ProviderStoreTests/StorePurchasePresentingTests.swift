import Foundation
import Testing
@testable import ProviderStore

/// `StorePurchasePresenting` 的契约行为。
@Suite("StorePurchasePresenting")
@MainActor
struct StorePurchasePresentingTests {

    /// 记录呈现调用的测试替身。
    private final class RecordingPresenter: StorePurchasePresenting {
        private(set) var presentCount = 0

        func presentPurchase() {
            presentCount += 1
        }
    }

    /// 呈现动作被转发到实现方。
    @Test func presentIsForwardedToImplementation() {
        let presenter = RecordingPresenter()

        presenter.presentPurchase()

        #expect(presenter.presentCount == 1)
    }

    /// 空实现在商店缺席时静默降级，不崩溃也不产生副作用。
    @Test func noopPresenterIsInert() {
        let presenter = NoopStorePurchasePresenting()

        presenter.presentPurchase()
        presenter.presentPurchase()
    }
}
