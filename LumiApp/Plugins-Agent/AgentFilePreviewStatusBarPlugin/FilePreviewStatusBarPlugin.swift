import Foundation
import SwiftUI
import os
import MagicKit

/// File Preview Status Bar Plugin: 显示文件预览状态栏信息（类似 VS Code）
actor FilePreviewStatusBarPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-preview-statusbar")

    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "📊"

    /// Whether to enable this plugin
    nonisolated static let enable = true

    /// Whether to enable verbose log output
    nonisolated static let verbose = false

    /// Plugin unique identifier
    static let id: String = "FilePreviewStatusBar"

    /// Plugin display name
    static let displayName: String = "文件预览状态栏"

    /// Plugin functional description
    static let description: String = "在 Agent 模式底部状态栏显示文件信息（文件类型、字符数等）"

    /// Plugin icon name
    static let iconName: String = "info.circle.fill"

    /// Whether it is configurable
    static let isConfigurable: Bool = false

    /// Registration order (higher number = loaded later, appears on the right side of status bar)
    static var order: Int { 91 }

    // MARK: - Instance

    /// Plugin instance label (used to identify unique instances)
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// Plugin singleton instance
    static let shared = FilePreviewStatusBarPlugin()

    /// Initialization method
    init() {
        // Init
    }

    // MARK: - UI Contributions

    /// Add status bar view for Agent mode - 显示文件预览状态栏
    /// - Returns: FilePreviewStatusBarView to be added to the bottom status bar
    @MainActor func addStatusBarView() -> AnyView? {
        if Self.verbose {
            Self.logger.info("\(self.t) 提供 FilePreviewStatusBarView")
        }
        return AnyView(FilePreviewStatusBarView())
    }
}
