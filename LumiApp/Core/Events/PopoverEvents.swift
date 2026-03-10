import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    /// 打开项目选择器的通知
    static let openProjectSelector = Notification.Name("openProjectSelector")

    /// 打开 MCP 设置的通知
    static let openMCPSettings = Notification.Name("openMCPSettings")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// 发送打开项目选择器的通知
    static func postOpenProjectSelector() {
        NotificationCenter.default.post(name: .openProjectSelector, object: nil)
    }

    /// 发送打开 MCP 设置的通知
    static func postOpenMCPSettings() {
        NotificationCenter.default.post(name: .openMCPSettings, object: nil)
    }
}

// MARK: - View Extensions

extension View {
    /// 监听打开项目选择器的事件
    func onOpenProjectSelector(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .openProjectSelector)) { _ in
            action()
        }
    }

    /// 监听打开 MCP 设置的事件
    func onOpenMCPSettings(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .openMCPSettings)) { _ in
            action()
        }
    }
}
