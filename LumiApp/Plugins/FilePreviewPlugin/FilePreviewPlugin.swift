import Foundation
import SwiftUI
import OSLog
import MagicKit

/// File Preview Plugin: 显示当前选择文件的内容预览
actor FilePreviewPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "📄"

    /// Whether to enable this plugin
    static let enable = true

    /// Whether to enable verbose log output
    nonisolated static let verbose = false

    /// Plugin unique identifier
    static let id: String = "FilePreview"

    /// Plugin display name
    static let displayName: String = "文件预览"

    /// Plugin functional description
    static let description: String = "显示当前选择文件的内容预览"

    /// Plugin icon name
    static let iconName: String = "doc.fill"

    /// Whether it is configurable
    static let isConfigurable: Bool = false

    /// Registration order
    static var order: Int { 76 }

    // MARK: - Instance

    /// Plugin instance label (used to identify unique instances)
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// Plugin singleton instance
    static let shared = FilePreviewPlugin()

    /// Initialization method
    init() {}

    // MARK: - UI Contributions

    /// Add middle view for Agent mode - 显示文件预览
    /// - Returns: FilePreviewView to be added to the middle column (only when file is selected)
    @MainActor func addMiddleView() -> AnyView? {
        // 只有在选择文件时才显示文件预览视图
        guard AgentProvider.shared.isFileSelected else {
            if Self.verbose {
                os_log("\(self.t) 未选择文件，不显示文件预览视图")
            }
            return nil
        }
        
        if Self.verbose {
            os_log("\(self.t) 提供 FilePreviewView")
        }
        return AnyView(FilePreviewView())
    }
}
