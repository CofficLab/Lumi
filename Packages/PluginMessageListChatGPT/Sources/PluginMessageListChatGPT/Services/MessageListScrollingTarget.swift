import Foundation
import SwiftUI

/// V5（ChatGPT）滚动协调器所需的最小滚动目标能力。
///
/// 协调器只认这个窄协议，不认 SwiftUI 具体类型，
/// 因此「何时滚、滚几次、重试策略、钉底收敛」这些有分支的逻辑
/// 可以脱离 SwiftUI 运行时做单测。
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

/// V5（ChatGPT）生产实现：把 `ScrollViewProxy` 与可选的
/// `ScrollViewBottomController` 组合成一个滚动目标。
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
