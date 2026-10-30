import CoreGraphics
import Foundation
import Testing
@testable import PluginMessageListStandard

/// 可编程的底部几何假实现，用于确定性地驱动 `settleBottom` 的收敛判据。
///
/// 生产环境中该角色由 `ScrollViewBottomController` 承担，内部持有真实
/// `NSScrollView`；正是这一点让收敛逻辑此前无法被测试覆盖。
@MainActor
final class ScriptedBottomGeometry: MessageListBottomGeometry {
    /// 每次 `pinToBottom()` 返回的快照序列；用完则重复最后一个。
    private(set) var scripted: [ScrollViewBottomController.Snapshot?]
    private(set) var pinCallCount = 0
    let isAttached: Bool

    init(
        scripted: [ScrollViewBottomController.Snapshot?],
        isAttached: Bool = true
    ) {
        self.scripted = scripted
        self.isAttached = isAttached
    }

    func pinToBottom() -> ScrollViewBottomController.Snapshot? {
        pinCallCount += 1
        guard !scripted.isEmpty else { return nil }
        let index = min(pinCallCount - 1, scripted.count - 1)
        return scripted[index]
    }
}

@MainActor
extension ScrollViewBottomController.Snapshot {
    static func snapshot(
        documentHeight: CGFloat,
        visibleHeight: CGFloat = 600,
        offsetY: CGFloat? = nil
    ) -> ScrollViewBottomController.Snapshot {
        ScrollViewBottomController.Snapshot(
            documentHeight: documentHeight,
            visibleHeight: visibleHeight,
            offsetY: offsetY ?? max(0, documentHeight - visibleHeight)
        )
    }
}

@MainActor
@Test("底部收敛：几何逐帧增长时应在稳定后退出，而不是耗尽全部重试")
func bottomSettleStopsOnceGeometrySettles() async {
    // 前 6 帧高度仍在增长（List 懒加载富文本行），之后稳定。
    let growing: [ScrollViewBottomController.Snapshot?] = (1...6).map {
        ScrollViewBottomController.Snapshot.snapshot(documentHeight: CGFloat(600 + $0 * 40))
    }
    let stable = ScrollViewBottomController.Snapshot.snapshot(documentHeight: 1000)
    let geometry = ScriptedBottomGeometry(scripted: growing + [stable])

    let coordinator = MessageListScrollCoordinator(settleDelayOverrideNs: 1_000_000)
    let attempts = await runSettle(coordinator: coordinator, geometry: geometry)

    // 稳定后应在少量帧内退出；耗尽 24 次即代表收敛判据失效。
    #expect(attempts < 12, "settleBottom 在几何已稳定后仍消耗了 \(attempts) 次尝试")
    #expect(geometry.pinCallCount < 12)
}

@MainActor
@Test("底部收敛：微小的亚像素抖动不应导致重置稳定计数")
func bottomSettleToleratesSubPixelJitter() async {
    // 高度仅在 0.2px 内抖动 —— 视觉上完全稳定，但严格阈值可能反复重置。
    let jittered: [ScrollViewBottomController.Snapshot?] = (0..<10).map { index in
        ScrollViewBottomController.Snapshot.snapshot(documentHeight: 1000 + CGFloat(index % 2) * 0.2)
    }
    let geometry = ScriptedBottomGeometry(scripted: jittered)

    let coordinator = MessageListScrollCoordinator(settleDelayOverrideNs: 1_000_000)
    let attempts = await runSettle(coordinator: coordinator, geometry: geometry)

    #expect(attempts < 12, "亚像素抖动使收敛重试了 \(attempts) 次")
}

@MainActor
@Test("底部收敛：未绑定滚动视图时应立即放弃，而不是空转")
func bottomSettleAbortsWhenGeometryUnavailable() async {
    let geometry = ScriptedBottomGeometry(scripted: [nil], isAttached: false)
    let coordinator = MessageListScrollCoordinator(settleDelayOverrideNs: 1_000_000)

    let attempts = await runSettle(coordinator: coordinator, geometry: geometry)

    #expect(attempts == 0, "几何不可用时仍空转了 \(attempts) 次")
}

/// 驱动一次收敛并返回实际尝试次数。
@MainActor
private func runSettle(
    coordinator: MessageListScrollCoordinator,
    geometry: ScriptedBottomGeometry
) async -> Int {
    let before = geometry.pinCallCount
    await coordinator.settleBottomForTesting(controller: geometry) { true }
    return geometry.pinCallCount - before
}
