import Foundation
import SwiftUI
import OSLog
import MagicKit

/// Agent Native File Tree Plugin: 使用 NSOutlineView 的高性能文件树
actor AgentNativeFileTreePlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🌲"
    nonisolated static let enable = true
    nonisolated static let verbose = true

    static let id: String = "AgentNativeFileTree"
    static let displayName: String = "高性能文件树"
    static let description: String = "使用原生 NSOutlineView 实现的高性能文件树"
    static let iconName: String = "folder.fill"
    static let isConfigurable: Bool = false
    static var order: Int { 76 }

    nonisolated var instanceLabel: String {
        Self.id
    }

    static let shared = AgentNativeFileTreePlugin()

    init() {
        if Self.verbose {
            os_log("\(Self.t)✅ AgentNativeFileTreePlugin 初始化完成")
        }
    }

    // MARK: - UI Contributions

    @MainActor func addSidebarView() -> AnyView? {
        if Self.verbose {
            os_log("\(Self.t)📋 addSidebarView 被调用")
        }
        return AnyView(AgentNativeFileTreeContainer())
    }
}
