import Foundation
import SwiftUI
import os

/// 窗口持久化插件：监听各窗口 VM 状态变化，防抖保存到磁盘（项目、会话、面板、编辑器等）。
actor WindowPersistencePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.window-persistence")

    nonisolated static let emoji = "🪟"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "WindowPersistence"
    static let displayName: String = String(localized: "Window Persistence", table: "WindowPersistence")
    static let description: String = String(localized: "Save window states when they change", table: "WindowPersistence")
    static let iconName: String = "macwindow"
    static var isConfigurable: Bool { false }
    static var order: Int { 999 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = WindowPersistencePlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    /// 根视图包裹：监听 VM 变化并保存窗口状态；启动恢复在 `onRegister` 注册
    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(WindowPersistenceOverlay(content: content()))
    }
}
