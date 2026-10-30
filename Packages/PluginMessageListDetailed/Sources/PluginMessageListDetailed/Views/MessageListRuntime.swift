import Foundation
import SwiftUI

/// 消息列表视图（V3 / 详细模式）的**运行时状态容器**。
///
/// ## 为什么需要它
///
/// `ListV3View` 是 struct，宿主（`ChatStackView.body` 里的 `item.makeView()`）
/// 每重绘一次就会重新 `init` 它一次。struct 的存储属性初始化表达式
/// **在每次 `init` 时都会执行**，因此用 `let` 持有有状态的引用类型对象时，
/// 它们每次都会被重建，之前攒的状态随之清零：
///
/// - `ScrollViewBottomController` 丢失 `NSScrollView` 绑定 → `isAttached == false`
///   → `MessageListScrollCoordinator.prepareInitialBottom` 退化为「只滚一次」，
///   不再等待 `List` 懒加载行物化完成，首屏位置可能停在半路；
/// - `MessageListScrollCoordinator` 丢失 `preparationSequence` / `scrollGeneration`
///   → 旧实例 `deinit` 时还会静默 cancel 掉正在进行的滚动任务；
///   更糟的是新旧两个实例的序号互不相识，`cancelPendingTasks()` 也 cancel
///   不掉对方，于是**两个协调器同时驱动同一个 scroll view**，几何收敛永远
///   不稳定，首屏遮罩就此永久挂起；
/// - `AtBottomBox` 丢失「用户是否在底部」→ 被重置为初值 `true`
///   → 用户明明已经上滚，流式跟随滚动却仍被开启。
///
/// 会话切换必然触发宿主重绘（`selectedConversationID.didSet` →
/// `notifyConversationObservers(.selected)` → `chat.refreshItems()` →
/// `objectWillChange.send()`），所以这个状态丢失**每次切换都会发生**。
///
/// 本容器由视图以 `@StateObject` 持有 —— SwiftUI 按视图 identity 缓存
/// `@StateObject` 的实例，于是三个成员的状态能跨宿主重绘存活。
///
/// ## 为什么成员不是 `ObservableObject`
///
/// - Important: 本类型**刻意不声明任何 `@Published`**。
///   成员（尤其 `AtBottomBox`）被刻意设计成不触发 SwiftUI invalidation，
///   以切断底部锚点 Preference 反馈环（`@State` → body 重建 → 偏好重报 → 活锁）。
///   详见 `AtBottomBox` 的类型注释。
///   容器本身实现 `ObservableObject` 只是为了满足 `@StateObject` 的要求；
///   它不发布任何属性，因此不会因此产生 invalidation。
@MainActor
final class MessageListRuntime: ObservableObject {
    /// 用户是否停在列表底部附近；用于决定新消息到达时是否自动滚到底部。
    let atBottomBox = AtBottomBox()

    /// 滚动策略协调器：首屏定位、底部收敛、锚点钉回。
    let scrollCoordinator = MessageListScrollCoordinator()

    /// 底层滚动视图控制器，供收敛循环读取真实几何。
    let bottomScrollController = ScrollViewBottomController()
}
