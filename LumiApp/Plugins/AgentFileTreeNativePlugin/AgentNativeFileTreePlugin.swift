import Foundation
import SwiftUI
import os
import MagicKit

/// Agent Native File Tree Plugin: 使用 NSOutlineView 的高性能文件树
actor AgentNativeFileTreePlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree-native")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "🌲"
    nonisolated static let enable = true
    nonisolated static let verbose = false

    static let id: String = "AgentNativeFileTree"
    static let displayName: String = String(localized: "File Tree", table: "AgentNativeFileTree")
    static let description: String = String(localized: "High-performance file tree using NSOutlineView", table: "AgentNativeFileTree")
    static let iconName: String = "folder.fill"
    static let isConfigurable: Bool = false
    static var order: Int { 76 }

    nonisolated var instanceLabel: String {
        Self.id
    }

    static let shared = AgentNativeFileTreePlugin()

    init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ AgentNativeFileTreePlugin 初始化完成")
        }
    }

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        if Self.verbose {
            Self.logger.info("\(Self.t)📝 AgentNativeFileTreePlugin 已注册")
        }
    }

    nonisolated func onEnable() {
        if Self.verbose {
            Self.logger.info("\(self.t)✅ AgentNativeFileTreePlugin 已启用")
        }
    }

    nonisolated func onDisable() {
        if Self.verbose {
            Self.logger.info("\(self.t)⛔️ AgentNativeFileTreePlugin 已禁用")
        }
    }

    // MARK: - Views

    @MainActor
    func addSidebarView() -> AnyView? {
        return AnyView(AgentNativeFileTreeContainer())
    }

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(FileTreeSyncOverlay(content: content()))
    }

    @MainActor
    func agentTools() -> [AgentTool] {
        [
            SelectFileTool(),
        ]
    }
}
