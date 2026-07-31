import Foundation
import LumiKernel
import SwiftUI

/// Message List Scroll Coordinator
///
/// 封装 `MessageListView` 中"与 SwiftUI 滚动行为耦合但与业务无关"的策略:
///
/// 1. **底部锚点判定**:`bottomAnchor` 几何位置进入视口下方 `bottomTolerance`pt
///    容差区时视为"用户在底部"——仅在布尔值真正翻转时写回 state,避免每帧
///    触发 View body 重建(preference 反复更新会导致 "Bound preference ...
///    tried to update multiple times per frame")。
/// 2. **底部滚动**:普通 `scrollToBottom(animated:)`,以及流式跟随滚到底
///    (无动画,避免高频 delta 抖动)。
/// 3. **post-layout 滚动**:prepend 之后等 `postLayoutDelayNs` 让新行布局
///    完成再把锚点行钉回视口顶部,避免视觉跳动。
///
/// 集中持有的魔法数字(48pt 容差、30ms / 50ms 延迟)来自原 `MessageListView`
/// 长期线上观察的经验值,保留注释以便调优时定位。
///
/// 本类型本身不持有任何可变状态 —— 所有方法都是无状态工具;View 通过
/// 直接调用即可,也可以用 `@State` 持有一个实例共享配置。
@MainActor
struct MessageListScrollCoordinator {
    /// 底部锚点行 id,用于 `isAtBottom` 检测和 `ScrollViewProxy.scrollTo`。
    static let bottomAnchorID = "message-list-bottom-anchor"

    /// 底部判定容差:底部锚点进入视口下方该范围内即视为在底部。
    /// 视口缩放/dpi 缩放变化时需重新校准。
    static let bottomTolerance: CGFloat = 48

    /// append 之后,等一帧让新内容布局再滚到底部的延迟。
    static let postAppendDelayNs: UInt64 = 30_000_000

    /// prepend 之后,等一帧让新行布局再钉回视口顶部的延迟。
    static let postPrependDelayNs: UInt64 = 50_000_000

    /// 根据底部锚点几何位置判断是否"在底部"。
    ///
    /// 视口或锚点几何为非有限值(初次布局尚未完成)时,直接返回当前值,
    /// 避免把 mid-layout 的 NaN/inf 写入 state。
    ///
    /// - Parameters:
    ///   - bottomMaxY: `bottomAnchor` 的全局 max-Y(由 preference 回调传入)。
    ///   - viewMaxY: 当前视口底部的全局 max-Y。
    ///   - current: 上一次的 `isAtBottom`。
    /// - Returns: 若与 `current` 相同则返回 `current`,否则返回新判定值;
    ///   调用方根据返回值是否等于旧值决定是否触发 state 写入。
    func resolveIsAtBottom(
        bottomMaxY: CGFloat,
        viewMaxY: CGFloat,
        current: Bool
    ) -> Bool {
        guard bottomMaxY.isFinite, viewMaxY.isFinite else { return current }
        let next = bottomMaxY <= viewMaxY + Self.bottomTolerance
        return next
    }

    /// 滚动到底部锚点。
    ///
    /// `animated == true` 时裹一层 `.easeOut(0.2s)`;
    /// `messages.isEmpty` 时不做任何滚动(无锚点可钉)。
    func scrollToBottom(proxy: ScrollViewProxy, messages: [LumiChatMessage], animated: Bool) {
        guard !messages.isEmpty else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
    }

    /// 等待 `postAppendDelayNs` 让新内容完成布局,再滚到底。
    ///
    /// 用于 `.onReceive(.lumiMessagesDidChange)`:tail refresh 完成后给 SwiftUI
    /// 一帧时间布局新行,避免滚到底时旧内容已就位但新行还没画上导致闪烁。
    func scrollToBottomAfterLayout(proxy: ScrollViewProxy, messages: [LumiChatMessage]) async {
        try? await Task.sleep(nanoseconds: Self.postAppendDelayNs)
        scrollToBottom(proxy: proxy, messages: messages, animated: true)
    }

    /// 等待 `postPrependDelayNs` 让 prepend 的新行完成布局,再把指定 id 钉回视口顶部。
    ///
    /// 用于"向上加载更早一页":保留原"加载前最顶部的消息"位置,防止 prepend 后
    /// 用户视觉位置跑掉。
    func pinToAnchor(proxy: ScrollViewProxy, anchorID: UUID) async {
        try? await Task.sleep(nanoseconds: Self.postPrependDelayNs)
        proxy.scrollTo(anchorID, anchor: .top)
    }
}
