import SwiftUI

// MARK: - Settings Window Identifier

/// 设置窗口的标识符常量
enum SettingsWindowID {
    /// 默认设置窗口 ID
    static let settings = "settings"
}

// MARK: - Notification Extension

extension Notification.Name {
    /// 打开设置视图的通知
    static let openSettings = Notification.Name("openSettings")

    /// 关闭设置视图的通知
    static let dismissSettings = Notification.Name("dismissSettings")

    /// 打开插件设置视图的通知
    static let openPluginSettings = Notification.Name("openPluginSettings")

    /// 插件设置变更的通知
    static let pluginSettingsChanged = Notification.Name("pluginSettingsChanged")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// 发送打开设置的通知
    /// - Parameter object: 可选的对象参数
    static func postOpenSettings(object: Any? = nil) {
        NotificationCenter.default.post(name: .openSettings, object: object)
    }

    /// 发送关闭设置的通知
    /// - Parameter object: 可选的对象参数
    static func postDismissSettings(object: Any? = nil) {
        NotificationCenter.default.post(name: .dismissSettings, object: object)
    }

    /// 发送打开插件设置的通知
    /// - Parameter object: 可选的对象参数
    static func postOpenPluginSettings(object: Any? = nil) {
        NotificationCenter.default.post(name: .openPluginSettings, object: object)
    }
}

// MARK: - View Extensions for Setting Events

extension View {
    /// 监听打开设置视图的事件
    /// - Parameter action: 事件处理闭包
    /// - Returns: 修改后的视图
    func onOpenSettings(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            action()
        }
    }

    /// 监听关闭设置视图的事件
    /// - Parameter action: 事件处理闭包
    /// - Returns: 修改后的视图
    func onDismissSettings(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .dismissSettings)) { _ in
            action()
        }
    }

    /// 监听打开插件设置视图的事件
    /// - Parameter action: 事件处理闭包
    /// - Returns: 修改后的视图
    func onOpenPluginSettings(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .openPluginSettings)) { _ in
            action()
        }
    }
}
