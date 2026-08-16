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
struct MessageListScrollCoordinator {
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

    /// 滚动到底部锚点。
    ///
    /// `animated == true` 时裹一层 `.easeOut(0.2s)`；
    /// `messages.isEmpty` 时不做任何滚动（无锚点可钉）。
    /// - Parameter condition: 每次真正滚动前（含重试）调用的前置条件，默认永真。
    func scrollToBottom(
        proxy: ScrollViewProxy,
        messages: [Message],
        animated: Bool,
        condition: @escaping @MainActor () -> Bool = { true }
    ) {
        guard !messages.isEmpty, condition() else { return }
        performScrollToBottom(proxy: proxy, animated: animated)
        // macOS 14 首次布局未完成时 scrollTo 会静默丢失，补一次重试。
        // 重试前再次检查条件 —— 用户可能在 100ms 窗口内手动滚离了底部。
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.scrollRetryDelayNs)
            guard condition() else { return }
            performScrollToBottom(proxy: proxy, animated: animated)
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

    /// 等待 `postAppendDelayNs` 让新内容完成布局，再滚到底。
    ///
    /// 流式期间（`animated == false`）不要动画：tail 刷新在流式中每条消息都会
    /// 触发，带动画的 `scrollTo` 会不断把目标重定到正在增长的底部，动画永不收敛。
    func scrollToBottomAfterLayout(
        proxy: ScrollViewProxy,
        messages: [Message],
        animated: Bool = true,
        condition: @escaping @MainActor () -> Bool = { true }
    ) async {
        try? await Task.sleep(nanoseconds: Self.postAppendDelayNs)
        scrollToBottom(proxy: proxy, messages: messages, animated: animated, condition: condition)
    }

    /// 等待 `postPrependDelayNs` 让 prepend 的新行完成布局，再把指定 id 钉回视口顶部。
    func pinToAnchor(proxy: ScrollViewProxy, anchorID: UUID) async {
        try? await Task.sleep(nanoseconds: Self.postPrependDelayNs)
        proxy.scrollTo(anchorID, anchor: .top)
    }
}
