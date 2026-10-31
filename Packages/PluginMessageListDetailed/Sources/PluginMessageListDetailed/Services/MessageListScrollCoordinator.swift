import Foundation
import ProviderMessage
import SwiftUI

/// Message List Scroll Coordinator
///
/// 封装 `MessageListView` 中"与 SwiftUI 滚动行为耦合但与业务无关"的策略：
///
/// 1. **底部滚动**：普通滚到底，以及流式跟随滚到底（无动画，避免高频 delta 抖动）。
/// 2. **post-layout 滚动**：prepend 之后等 `postPrependDelayNs` 让新行布局
///    完成再把锚点行钉回视口顶部，避免视觉跳动。
///
/// 「是否在底部」的判定由 `ScrollViewBottomTracker`（观察 NSScrollView）负责；
/// 实际滚动动作通过 `MessageListScrollingTarget` 执行，因此本协调器不依赖
/// `ScrollViewProxy`，可脱离 SwiftUI 运行时单测。
///
/// 集中持有的魔法数字（进入/离开容差、30ms / 50ms 延迟）来自原 `MessageListView`
/// 长期线上观察的经验值，保留注释以便调优时定位。
@MainActor
final class MessageListScrollCoordinator {
    /// 底部锚点行 id，用于 `ScrollViewProxy.scrollTo`（占位行挂在 List 末尾）。
    static let bottomAnchorID = "message-list-bottom-anchor"

    /// 进入阈值：不在底部时，内容底沿进入视口底下方该范围内才算"回到底部"。
    /// 迟滞判定由 `BottomEdgeEvaluator` 实现，此处仅为既有调用点的别名。
    static let bottomEnterTolerance: CGFloat = BottomEdgeEvaluator.enterTolerance
    /// 离开阈值：已在底部时，内容底沿低于视口底超过该范围才判定"离开底部"。
    /// 比 `bottomEnterTolerance` 更宽容，构成迟滞带，避免在容差边界抖动。
    static let bottomLeaveTolerance: CGFloat = BottomEdgeEvaluator.leaveTolerance

    /// append 之后，等一帧让新内容布局再滚到底部的延迟。
    static let postAppendDelayNs: UInt64 = 30_000_000
    /// prepend 之后，等一帧让新行布局再钉回视口顶部的延迟。
    static let postPrependDelayNs: UInt64 = 50_000_000
    /// macOS 14 上 List 尚未完成首次布局时，`scrollTo` 会静默失败；补一次重试。
    static let scrollRetryDelayNs: UInt64 = 100_000_000
    /// 富文本/懒加载行在滚动后仍可能继续改变 document 高度；持续钉底直到稳定。
    static let bottomSettleDelayNs: UInt64 = 50_000_000
    static let bottomSettleMaxAttempts = 24
    static let bottomSettleStableFrames = 3

    private var pendingBottomScrollTask: Task<Void, Never>?
    private var preparationSequence: UInt64 = 0
    private var scrollGeneration: UInt64 = 0

    deinit {
        pendingBottomScrollTask?.cancel()
    }

    /// 取消所有可能持有旧滚动目标的延迟操作。
    ///
    /// SwiftUI 重建或销毁 List 时，旧目标不能再参与下一轮 AttributeGraph
    /// 更新。所有列表宿主都在消失时调用此方法。
    func cancelPendingTasks() {
        pendingBottomScrollTask?.cancel()
        pendingBottomScrollTask = nil
        preparationSequence &+= 1
        scrollGeneration &+= 1
    }

    /// 在首次显示消息列表前完成布局并定位到底部。
    ///
    /// `List` 的首轮布局和懒加载行 materialize 都是异步的。调用方应在该方法
    /// 返回 `true` 后再撤掉遮罩，否则用户可能先看到列表顶部，再看到它跳到底部。
    ///
    /// - Returns: `true` 表示定位完成、可以撤遮罩；`false` 表示被取消、
    ///   `condition` 不成立或准备过程被新的一轮取代。
    @discardableResult
    func prepareInitialBottom(
        target: any MessageListScrollingTarget,
        messages: [Message],
        condition: @escaping @MainActor () -> Bool = { true }
    ) async -> Bool {
        pendingBottomScrollTask?.cancel()
        pendingBottomScrollTask = nil
        preparationSequence &+= 1
        let sequence = preparationSequence

        guard !messages.isEmpty else { return true }

        do {
            try await Task.sleep(nanoseconds: Self.postAppendDelayNs)
        } catch {
            return false
        }
        guard isPreparationActive(sequence), condition() else { return false }

        target.scrollToBottom(animated: false)

        do {
            try await Task.sleep(nanoseconds: Self.scrollRetryDelayNs)
        } catch {
            return false
        }
        guard isPreparationActive(sequence), condition() else { return false }

        if target.isAttached {
            await settleBottom(target: target) {
                self.isPreparationActive(sequence) && condition()
            }
        } else if condition() {
            target.scrollToBottom(animated: false)
        }

        return isPreparationActive(sequence) && condition()
    }

    private func isPreparationActive(_ sequence: UInt64) -> Bool {
        sequence == preparationSequence && !Task.isCancelled
    }

    /// 滚动到底部锚点。
    ///
    /// 底层目标已附着底层滚动视图时，改为进入多帧收敛模式（懒加载行仍在增长）。
    /// - Parameter condition: 每次真正滚动前（含重试）调用的前置条件，默认永真。
    func scrollToBottom(
        target: any MessageListScrollingTarget,
        messages: [Message],
        animated: Bool,
        condition: @escaping @MainActor () -> Bool = { true }
    ) {
        pendingBottomScrollTask?.cancel()
        pendingBottomScrollTask = nil
        guard !messages.isEmpty, condition() else { return }
        target.scrollToBottom(animated: animated)
        // macOS 14 首次布局未完成时 scrollTo 会静默丢失，补一次重试。
        // 重试前再次检查条件 —— 用户可能在 100ms 窗口内手动滚离了底部。
        pendingBottomScrollTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.scrollRetryDelayNs)
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            guard condition() else { return }
            if target.isAttached {
                await self.settleBottom(target: target, condition: condition)
            } else {
                target.scrollToBottom(animated: animated)
            }
        }
    }

    /// 在底层滚动视图中反复钉住真实 document 底边，等待 List 的 lazy 行布局稳定。
    private func settleBottom(
        target: any MessageListScrollingTarget,
        condition: @escaping @MainActor () -> Bool
    ) async {
        var previous: ScrollViewBottomController.Snapshot?
        var stableFrames = 0

        for _ in 0..<Self.bottomSettleMaxAttempts {
            guard !Task.isCancelled, condition() else { return }
            guard let current = target.pinToBottom() else { return }

            if let previous,
               abs(current.documentHeight - previous.documentHeight) < 0.5,
               abs(current.visibleHeight - previous.visibleHeight) < 0.5,
               abs(current.offsetY - previous.offsetY) < 0.5 {
                stableFrames += 1
                if stableFrames >= Self.bottomSettleStableFrames { return }
            } else {
                stableFrames = 0
            }
            previous = current

            do {
                try await Task.sleep(nanoseconds: Self.bottomSettleDelayNs)
            } catch {
                return
            }
        }
    }

    /// 等待 `postAppendDelayNs` 让新内容完成布局，再滚到底。
    ///
    /// 同一轮布局稳定期间只保留一个任务，避免流式 token 更新不断取消
    /// 30ms 延迟，导致连续输出期间一次真正的滚动都无法执行。
    /// 流式期间（`animated == false`）不要动画：tail 刷新在流式中每条消息都会
    /// 触发，带动画的 `scrollTo` 会不断把目标重定到正在增长的底部，动画永不收敛。
    func scheduleScrollToBottomAfterLayout(
        target: any MessageListScrollingTarget,
        messages: [Message],
        animated: Bool = true,
        condition: @escaping @MainActor () -> Bool = { true }
    ) {
        // If a scroll/settle pass is already active, it observes the current
        // document height repeatedly and will absorb subsequent token updates.
        // Debouncing by cancellation here starves the scroll during a steady
        // stream (each update arrives before the 30ms delay expires).
        guard pendingBottomScrollTask == nil else { return }

        let generation = scrollGeneration
        pendingBottomScrollTask = Task { @MainActor [weak self] in
            defer {
                if let self, self.scrollGeneration == generation {
                    self.pendingBottomScrollTask = nil
                }
            }
            do {
                try await Task.sleep(nanoseconds: Self.postAppendDelayNs)
            } catch {
                return
            }
            guard let self,
                  !Task.isCancelled,
                  generation == self.scrollGeneration,
                  !messages.isEmpty,
                  condition() else { return }

            target.scrollToBottom(animated: animated)

            do {
                try await Task.sleep(nanoseconds: Self.scrollRetryDelayNs)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  generation == self.scrollGeneration,
                  condition() else { return }

            if target.isAttached {
                await self.settleBottom(target: target, condition: condition)
            } else {
                target.scrollToBottom(animated: animated)
            }
        }
    }

    /// 等待 `postPrependDelayNs` 让 prepend 的新行完成布局，再把指定 id 钉回视口顶部。
    func pinToAnchor(target: any MessageListScrollingTarget, anchorID: UUID) async {
        let generation = scrollGeneration
        try? await Task.sleep(nanoseconds: Self.postPrependDelayNs)
        guard !Task.isCancelled, generation == scrollGeneration else { return }
        target.scrollToAnchorTop(anchorID)
    }
}
