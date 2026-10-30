import Foundation
import SwiftUI

/// 滚动协调器所需的最小滚动目标能力。
///
/// 协调器原本直接接收 `ScrollViewProxy`，导致「何时滚、滚几次、重试策略、
/// 钉底收敛」这些真正有分支的逻辑无法脱离 SwiftUI 运行时做单测。这里把
/// 三件事收敛成一个窄协议：
///
/// 1. `scrollToBottom` —— 滚到列表末尾锚点（生产实现包 `proxy.scrollTo`）。
/// 2. `scrollToAnchorTop` —— prepend 后把锚点行钉回视口顶部。
/// 3. `isAttached` / `pinToBottom` —— 底层 `NSScrollView` 的钉底能力，
///    用于 List 懒加载行仍在增长时的多帧收敛。
@MainActor
protocol MessageListScrollingTarget: AnyObject {
    /// 底层滚动视图是否已附着。未附着时协调器退化为「只调一次 proxy 滚动」。
    var isAttached: Bool { get }

    /// 把底层滚动视图钉到真实 document 底边，返回几何快照。
    /// 返回 `nil` 表示当前不可用（未附着 / documentView 缺失 / 几何非法）。
    func pinToBottom() -> ScrollViewBottomController.Snapshot?

    /// 滚动到底部锚点行。
    func scrollToBottom(animated: Bool)

    /// 把指定锚点行钉回视口顶部。
    func scrollToAnchorTop(_ anchorID: UUID)
}

/// 生产实现：把 `ScrollViewProxy` 与可选的 `ScrollViewBottomController` 组合成
/// 一个滚动目标。协调器只认协议，不认 SwiftUI 具体类型。
@MainActor
final class ProxyMessageListScrollingTarget: MessageListScrollingTarget {
    private let proxy: ScrollViewProxy
    private weak var controller: ScrollViewBottomController?

    init(proxy: ScrollViewProxy, controller: ScrollViewBottomController?) {
        self.proxy = proxy
        self.controller = controller
    }

    var isAttached: Bool { controller?.isAttached ?? false }

    func pinToBottom() -> ScrollViewBottomController.Snapshot? {
        controller?.pinToBottom()
    }

    func scrollToBottom(animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(MessageListScrollCoordinator.bottomAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(MessageListScrollCoordinator.bottomAnchorID, anchor: .bottom)
        }
    }

    func scrollToAnchorTop(_ anchorID: UUID) {
        proxy.scrollTo(anchorID, anchor: .top)
    }
}
