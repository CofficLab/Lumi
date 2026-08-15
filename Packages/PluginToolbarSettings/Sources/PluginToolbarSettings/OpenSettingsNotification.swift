import Foundation

/// 打开设置窗口的通知名。
///
/// 工具栏设置按钮点击后发出；宿主 App 监听并打开设置窗口，
/// 从而与具体窗口 id 解耦。
public extension Notification.Name {
    static let lumiOpenSettings = Notification.Name("lumi.openSettings")
}
