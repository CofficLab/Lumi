import Foundation
import KitMessageList

/// V5（ChatGPT）列表的运行时状态容器。
///
/// 集中持有「跨视图共享但不需要触发 SwiftUI 重绘」的运行时对象：
/// - `atBottomBox` —— 「是否在底部」布尔值，由滚动观察器高频写入；
/// - `bottomScrollController` —— 底层 `NSScrollView` 的钉底控制器；
/// - `scrollCoordinator` —— 贴底收敛与 prepend 锚点回钉的编排。
///
/// - Important: 必须是 `@StateObject`，不能用 `let`。
///   宿主每重绘一次就会重新 `init` 本视图一次；`let` 持有的状态对象会被
///   重建，新旧两个滚动协调器会同时驱动同一个 scroll view，
///   首屏遮罩永久挂起。
///
/// - Note: `atBottomBox` 刻意不实现 `ObservableObject` ——
///   它被高频滚动回调写入，实现 `ObservableObject` 会形成
///   「写入 → 重绘 → 布局 → 滚动 → 写入」的反馈环。
@MainActor
final class MessageListRuntime: ObservableObject {
    /// 「是否在底部」的可变盒子。
    let atBottomBox = AtBottomBox()

    /// 底层滚动视图的钉底控制器。
    let bottomScrollController = ScrollViewBottomController()

    /// 滚动协调器。
    let scrollCoordinator = MessageListScrollCoordinator()

    init() {}
}
