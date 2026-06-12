import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// 窗口持久化插件：监听各窗口 VM 状态变化，防抖保存到磁盘（项目、会话、面板、编辑器等）。
public actor WindowPersistencePlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.window-persistence")

    public nonisolated static let emoji = "🪟"
    public static var category: PluginCategory { .general }
    public nonisolated static let verbose: Bool = false
    public static let id: String = "WindowPersistence"
    public static let displayName: String = LumiPluginLocalization.string("Window Persistence", bundle: .module)
    public static let description: String = LumiPluginLocalization.string("Save window states when they change", bundle: .module)
    public static let iconName: String = "macwindow"
    public static var order: Int { 999 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = WindowPersistencePlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

}
