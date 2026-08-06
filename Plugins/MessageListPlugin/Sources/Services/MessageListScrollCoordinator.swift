import Foundation
import LumiKernel
import SwiftUI

/// Message List Scroll Coordinator
///
/// 封装 `MessageListView` 中"与 SwiftUI 滚动行为耦合但与业务无关"的策略:
///
/// 1. **底部滚动**:普通 `scrollToBottom(animated:)`,以及流式跟随滚到底
///    (无动画,避免高频 delta 抖动)。
/// 2. **post-layout 滚动**:prepend 之后等 `postPrependDelayNs` 让新行布局
///    完成再把锚点行钉回视口顶部,避免视觉跳动。
///
/// 「是否在底部」的判定已迁移到 `ScrollViewBottomTracker`(观察 NSScrollView,
/// 见其文档),不再由本类型负责 —— 旧的 GeometryReader + Preference 方案在
/// 流式场景下会触发 LazyVStack 活锁。
///
/// 集中持有的魔法数字(进入/离开容差、30ms / 50ms 延迟)来自原 `MessageListView`
/// 长期线上观察的经验值,保留注释以便调优时定位。
///
/// 本类型本身不持有任何可变状态 —— 所有方法都是无状态工具;View 通过
/// 直接调用即可,也可以用 `@State` 持有一个实例共享配置。
@MainActor
struct MessageListScrollCoordinator {
    /// 底部锚点行 id,用于 `ScrollViewProxy.scrollTo`(占位行挂在 LazyVStack 末尾)。
    static let bottomAnchorID = "message-list-bottom-anchor"

    /// 进入阈值:不在底部时,内容底沿进入视口底下方该范围内才算"回到底部"。
    /// 视口缩放/dpi 缩放变化时需重新校准。
    /// 由 `ScrollViewBottomTracker`(观察 NSScrollView)使用。
    static let bottomEnterTolerance: CGFloat = 24

    /// 离开阈值:已在底部时,内容底沿低于视口底超过该范围才判定"离开底部"。
    /// 比 `bottomEnterTolerance` 更宽容,构成迟滞带 —— 滚动在容差边界抖动时
    /// 不会反复翻转,避免无谓回调。
    /// 由 `ScrollViewBottomTracker` 使用。
    static let bottomLeaveTolerance: CGFloat = 96

    /// append 之后,等一帧让新内容布局再滚到底部的延迟。
    static let postAppendDelayNs: UInt64 = 30_000_000

    /// prepend 之后,等一帧让新行布局再钉回视口顶部的延迟。
    static let postPrependDelayNs: UInt64 = 50_000_000

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
    ///
    /// 流式期间(`animated == false`)不要动画:tail 刷新在流式中每条消息都会
    /// 触发,带动画的 `scrollTo` 会不断把目标重定到正在增长的底部,动画永不收敛,
    /// 是 AttributeGraph 活锁的诱因之一。仅在用户发完消息、非流式刷新时用动画。
    func scrollToBottomAfterLayout(
        proxy: ScrollViewProxy,
        messages: [LumiChatMessage],
        animated: Bool = true
    ) async {
        try? await Task.sleep(nanoseconds: Self.postAppendDelayNs)
        scrollToBottom(proxy: proxy, messages: messages, animated: animated)
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
