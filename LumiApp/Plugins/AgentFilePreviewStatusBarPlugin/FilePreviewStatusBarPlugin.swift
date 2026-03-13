import Foundation
import SwiftUI
import OSLog
import MagicKit

/// File Preview Status Bar Plugin: 显示文件预览底部状态栏
actor FilePreviewStatusBarPlugin: SuperPlugin, SuperLog {
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
    static let description: String = "显示文件预览底部状态栏（文件类型、字符数等）"

    /// Plugin icon name
    static let iconName: String = "info.circle.fill"

    /// Whether it is configurable
    static let isConfigurable: Bool = true

    /// Registration order (after FilePreviewPlugin to appear at the bottom of middle column)
    static var order: Int { 77 }

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

    /// Add middle view for Agent mode - 显示文件预览状态栏
    /// - Returns: FilePreviewStatusBarView to be added to the bottom of middle column
    @MainActor func addMiddleView() -> AnyView? {
        if Self.verbose {
            os_log("\(self.t) 提供 FilePreviewStatusBarView")
        }
        return AnyView(FilePreviewStatusBarView())
    }
}
