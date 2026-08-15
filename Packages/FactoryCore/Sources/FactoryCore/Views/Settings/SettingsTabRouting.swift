import Combine
import Foundation

/// 设置窗口的标签路由。
///
/// `.lumiOpenSettingsTab` 通知可能发生在设置窗口尚未打开时（此时
/// `WindowMain` 才刚调用 `openWindow`，`SettingsView` 尚未创建、无法订阅
/// 通知），因此用共享的单例状态承载目标标签：`WindowMain` 写入，
/// `SettingsView` 在出现时及后续变更时消费并清除。
@MainActor
final class SettingsTabRouting: ObservableObject {
    static let shared = SettingsTabRouting()

    /// 请求定位到的设置标签 id；被 `SettingsView` 消费后置回 `nil`。
    @Published var requestedTabID: String?

    private init() {}
}
