import Foundation
import SwiftUI
import os
import MagicKit
import Combine

/// File Preview Plugin: 显示当前选择文件的内容预览
actor FilePreviewPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-preview")

    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "📄"

    /// Whether to enable this plugin
    nonisolated static let enable = true

    /// Whether to enable verbose log output
    nonisolated static let verbose = false

    /// Plugin unique identifier
    static let id: String = "FilePreview"

    /// Plugin display name
    static let displayName: String = String(localized: "文件预览", table: "FilePreview")

    /// Plugin functional description
    static let description: String = String(localized: "显示当前选择文件的内容预览", table: "FilePreview")

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

    /// 当前是否选择了文件
    @MainActor private var isFileSelected: Bool = false

    /// Initialization method
    init() {
        // 监听文件选择变化通知
        NotificationCenter.default.addObserver(
            forName: .fileSelectionChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.checkFileSelection()
            }
        }
    }

    /// 检查文件选择状态
    @MainActor
    private func checkFileSelection() {
        isFileSelected.toggle()
    }

    // MARK: - UI Contributions

    /// Add detail view - 显示文件预览
    /// - Returns: FilePreviewView to be shown in the detail panel
    @MainActor func addDetailView() -> AnyView? {
        AnyView(FilePreviewView())
    }

    /// 添加 Agent 模式底部状态栏右侧视图 - 显示当前主题
    /// - Returns: FilePreviewThemeStatusBarView to be shown in the status bar
    @MainActor func addStatusBarTrailingView() -> AnyView? {
        AnyView(FilePreviewThemeStatusBarView())
    }
}
