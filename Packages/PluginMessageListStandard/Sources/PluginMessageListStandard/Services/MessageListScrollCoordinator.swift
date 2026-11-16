import Foundation
import ProviderMessage
import SwiftUI

/// Message List Scroll Coordinator
///
/// 封装 `MessageListView` 中"与 SwiftUI 滚动行为耦合但与业务无关"的策略：
///
/// 1. **底部滚动**：普通 `scrollToBottom(animated:)`，以及流式跟随滚到底
///    （无动画，避免高频 delta 抖动）。
/// 2. **post-layout 滚动**：prepend 之后等 `postPrependDelayNs` 让新行布局
///    完成再把锚点行钉回视口顶部，避免视觉跳动。
///
/// 「是否在底部」的判定由 `ScrollViewBottomTracker`（观察 NSScrollView）负责。
///
/// 集中持有的魔法数字（进入/离开容差、30ms / 50ms 延迟）来自原 `MessageListView`
/// 长期线上观察的经验值，保留注释以便调优时定位。
@MainActor
final class MessageListScrollCoordinator {
    /// 底部锚点行 id，用于 `ScrollViewProxy.scrollTo`（占位行挂在 List 末尾）。
    static let bottomAnchorID = "message-list-bottom-anchor"

    /// 进入阈值：不在底部时，内容底沿进入视口底下方该范围内才算"回到底部"。
    static let bottomEnterTolerance: CGFloat = 24
    /// 离开阈值：已在底部时，内容底沿低于视口底超过该范围才判定"离开底部"。
    /// 比 `bottomEnterTolerance` 更宽容，构成迟滞带，避免在容差边界抖动。
    static let bottomLeaveTolerance: CGFloat = 96

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
    /// `bottomSettleDelayNs` 的可覆盖副本，仅供测试把收敛循环压到毫秒级。
    /// 生产代码不设置，行为与常量完全一致。
    private let settleDelayOverrideNs: UInt64?
    private var preparationSequence: UInt64 = 0
    private var scrollGeneration: UInt64 = 0
    /// 锚点恢复的代次：新的恢复或任何底部意图都会让它失效（#1330）。
    private var anchorGeneration: UInt64 = 0
    /// 正在执行锚点恢复的控制器；用于在底部意图到来时解除 tracker 抑制。
    private weak var anchorRestoreController: ScrollViewBottomController?

    init(settleDelayOverrideNs: UInt64? = nil) {
        self.settleDelayOverrideNs = settleDelayOverrideNs
    }

    deinit {
        pendingBottomScrollTask?.cancel()
    }

    /// 取消所有可能持有旧 `ScrollViewProxy` 的延迟操作。
    ///
    /// SwiftUI 重建或销毁 List 时，旧 proxy 不能再参与下一轮 AttributeGraph
    /// 更新。所有列表宿主都在消失时调用此方法。
    func cancelPendingTasks() {
        pendingBottomScrollTask?.cancel()
        pendingBottomScrollTask = nil
        preparationSequence &+= 1
        scrollGeneration &+= 1
        invalidateAnchorRestore()
    }

    /// 打断进行中的锚点恢复并解除 tracker 抑制（#1330）。
    ///
    /// 任何「滚到底」意图（新消息、首屏定位、会话切换）都优先于锚点恢复：
    /// 恢复循环在下一个检查点自行退出，抑制标记必须在这里立即清除，
    /// 否则后续的底部跟随会被 tracker 的增长钉底抑制卡住。
    private func invalidateAnchorRestore() {
        anchorGeneration &+= 1
        anchorRestoreController?.isRestoringAnchor = false
        anchorRestoreController = nil
    }

    /// 在首次显示消息列表前完成布局并定位到底部。
    ///
    /// `List` 的首轮布局和懒加载行 materialize 都是异步的。调用方应在该方法
    /// 返回 `true` 后再撤掉遮罩，否则用户可能先看到列表顶部，再看到它跳到底部。
    func prepareInitialBottom(
        proxy: ScrollViewProxy,
        messages: [Message],
        controller: ScrollViewBottomController? = nil,
        condition: @escaping @MainActor () -> Bool = { true }
    ) async -> Bool {
        pendingBottomScrollTask?.cancel()
        pendingBottomScrollTask = nil
        preparationSequence &+= 1
        invalidateAnchorRestore()
        let sequence = preparationSequence

        guard !messages.isEmpty else { return true }

        do {
            try await Task.sleep(nanoseconds: Self.postAppendDelayNs)
        } catch {
            return false
        }
        guard isPreparationActive(sequence), condition() else { return false }

        performScrollToBottom(proxy: proxy, animated: false)

        do {
            try await Task.sleep(nanoseconds: Self.scrollRetryDelayNs)
        } catch {
            return false
        }
        guard isPreparationActive(sequence), condition() else { return false }

        if let controller, controller.isAttached {
            await settleBottom(controller: controller) {
                self.isPreparationActive(sequence) && condition()
            }
        } else if condition() {
            performScrollToBottom(proxy: proxy, animated: false)
        }

        return isPreparationActive(sequence) && condition()
    }

    /// 仅供测试驱动收敛循环。收敛判据是本组件最易回归的部分，
    /// 但它依赖真实滚动视图，必须留出无窗口依赖的测试缝。
    func settleBottomForTesting(
        controller: any MessageListBottomGeometry,
        condition: @escaping @MainActor () -> Bool = { true }
    ) async {
        await settleBottom(controller: controller, condition: condition)
    }

    private func isPreparationActive(_ sequence: UInt64) -> Bool {
        sequence == preparationSequence && !Task.isCancelled
    }

    /// 滚动到底部锚点。
    ///
    /// `animated == true` 时裹一层 `.easeOut(0.2s)`；
    /// `messages.isEmpty` 时不做任何滚动（无锚点可钉）。
    /// - Parameter condition: 每次真正滚动前（含重试）调用的前置条件，默认永真。
    func scrollToBottom(
        proxy: ScrollViewProxy,
        messages: [Message],
        animated: Bool,
        controller: ScrollViewBottomController? = nil,
        condition: @escaping @MainActor () -> Bool = { true }
    ) {
        pendingBottomScrollTask?.cancel()
        pendingBottomScrollTask = nil
        invalidateAnchorRestore()
        guard !messages.isEmpty, condition() else { return }
        performScrollToBottom(proxy: proxy, animated: animated)
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
            if let controller, controller.isAttached {
                await self.settleBottom(controller: controller, condition: condition)
            } else {
                self.performScrollToBottom(proxy: proxy, animated: animated)
            }
        }
    }

    private func performScrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
    }

    /// 在底层滚动视图中反复钉住真实 document 底边，等待 List 的 lazy 行布局稳定。
    private func settleBottom(
        controller: any MessageListBottomGeometry,
        condition: @escaping @MainActor () -> Bool
    ) async {
        var previous: ScrollViewBottomController.Snapshot?
        var stableFrames = 0

        // - Important: 控制器未绑定滚动视图时**立即放弃**，不要进入循环。
        //   切换会话会让 List 因 `.id(selectedConversationID)` 重建，tracker 的
        //   `attachIfNeeded()` 尚未完成；此时 `pinToBottom()` 必然返回 nil。
        //   不预先检查就会白白消耗一轮，并在 50ms 睡眠后才 return，
        //   让「遮罩撤除」整体后移。调用方虽有 `isAttached` 判断，但那存在
        //   检查与进入之间的时序窗口，此处的检查才是权威判定。
        guard controller.isAttached else { return }

        for _ in 0..<Self.bottomSettleMaxAttempts {
            guard !Task.isCancelled, anchorRestoreController == nil, condition() else { return }
            guard let current = controller.pinToBottom() else { return }

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
                try await Task.sleep(nanoseconds: settleDelayOverrideNs ?? Self.bottomSettleDelayNs)
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
        proxy: ScrollViewProxy,
        messages: [Message],
        animated: Bool = true,
        controller: ScrollViewBottomController? = nil,
        condition: @escaping @MainActor () -> Bool = { true }
    ) {
        // If a scroll/settle pass is already active, it observes the current
        // document height repeatedly and will absorb subsequent token updates.
        // Debouncing by cancellation here starves the scroll during a steady
        // stream (each update arrives before the 30ms delay expires).
        guard pendingBottomScrollTask == nil else { return }
        invalidateAnchorRestore()

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

            self.performScrollToBottom(proxy: proxy, animated: animated)

            do {
                try await Task.sleep(nanoseconds: Self.scrollRetryDelayNs)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  generation == self.scrollGeneration,
                  condition() else { return }

            if let controller, controller.isAttached {
                await self.settleBottom(controller: controller, condition: condition)
            } else {
                self.performScrollToBottom(proxy: proxy, animated: animated)
            }
        }
    }

    /// 等待 `postPrependDelayNs` 让 prepend 的新行完成布局，再把指定 id 钉回视口顶部。
    ///
    /// 互斥（#1330）：prepend 与「跟随滚到底」是两种互斥意图。进入时先取消
    /// 已排程的底部滚动、作废在途的钉底收敛循环，并通知底部追踪器在恢复期间
    /// 抑制「文档长高 → 钉底」——否则 tracker 会把 prepend 的高度增长当成
    /// 新消息，把用户拽到新的底部。
    ///
    /// 重试：大 prepend 之后懒加载行高会持续修正，单次 `scrollTo` 可能落在
    /// 错误偏移；仿照 `settleBottom` 重试到文档高度稳定为止。
    func pinToAnchor(
        proxy: ScrollViewProxy,
        anchorID: UUID,
        controller: ScrollViewBottomController? = nil
    ) async {
        pendingBottomScrollTask?.cancel()
        pendingBottomScrollTask = nil
        scrollGeneration &+= 1
        let generation = scrollGeneration
        anchorGeneration &+= 1
        let anchorSequence = anchorGeneration
        anchorRestoreController = controller
        controller?.isRestoringAnchor = true
        defer {
            if anchorSequence == anchorGeneration {
                controller?.isRestoringAnchor = false
                anchorRestoreController = nil
            }
        }

        try? await Task.sleep(nanoseconds: Self.postPrependDelayNs)
        guard !Task.isCancelled,
              generation == scrollGeneration,
              anchorSequence == anchorGeneration else { return }
        proxy.scrollTo(anchorID, anchor: .top)

        var previousHeight: CGFloat?
        var stableFrames = 0
        for _ in 0..<Self.bottomSettleMaxAttempts {
            try? await Task.sleep(nanoseconds: Self.bottomSettleDelayNs)
            guard !Task.isCancelled,
                  generation == scrollGeneration,
                  anchorSequence == anchorGeneration else { return }
            guard let height = controller?.geometrySnapshot()?.documentHeight else { return }

            if let previousHeight, abs(height - previousHeight) < 0.5 {
                stableFrames += 1
                if stableFrames >= Self.bottomSettleStableFrames { return }
            } else {
                stableFrames = 0
            }
            previousHeight = height
            proxy.scrollTo(anchorID, anchor: .top)
        }
    }
}
