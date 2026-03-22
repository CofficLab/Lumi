import SwiftUI

// MARK: - Notification Extension

extension Notification.Name {
    /// 插件扫描完成的通知
    /// object: nil
    static let pluginsDidLoad = Notification.Name("PluginsDidLoad")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// 发送插件扫描完成的通知
    static func postPluginsDidLoad() {
        NotificationCenter.default.post(
            name: .pluginsDidLoad,
            object: nil
        )
    }
}

// MARK: - View Extensions for Plugin Events

extension View {
    /// 监听插件扫描完成的事件
    /// - Parameter action: 事件处理闭包
    /// - Returns: 修改后的视图
    func onPluginsDidLoad(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .pluginsDidLoad)) { _ in
            action()
        }
    }
}