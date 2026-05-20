import Foundation
import SwiftUI
import os

/// 窗口持久化插件：负责保存和恢复窗口状态（当前项目、会话、面板、编辑器、侧边栏）
/// 监听窗口关闭事件，自动保存窗口快照到磁盘。
/// 启动时从磁盘恢复窗口状态。
actor WindowPersistencePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.window-persistence")

    nonisolated static let emoji = "🪟"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "WindowPersistence"
    static let displayName: String = String(localized: "Window Persistence", table: "WindowPersistence")
    static let description: String = String(localized: "Save and restore window states across app launches", table: "WindowPersistence")
    static let iconName: String = "macwindow"
    static var isConfigurable: Bool { false }
    static var order: Int { 999 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = WindowPersistencePlugin()

    nonisolated func onRegister() {
        Task { @MainActor in
            WindowPersistenceCoordinator.warmUp()
        }
    }
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    /// 根视图包裹：用于窗口状态的恢复和保存
    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(WindowRestoreOverlay(content: content()))
    }
}
