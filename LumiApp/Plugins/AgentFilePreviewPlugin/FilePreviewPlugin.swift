import Foundation
import SwiftUI
import OSLog
import MagicKit
import Combine

/// File Preview Plugin: 显示当前选择文件的内容预览
actor FilePreviewPlugin: SuperPlugin, SuperLog {
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

    /// 当前是否选择了文件
    @MainActor private var isFileSelected: Bool = false

    /// Initialization method
    init() {
        // 监听文件选择变化通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AgentProviderFileSelectionChanged"),
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
        // 由于无法直接访问 AgentProvider，这里使用一个简单的启发式方法
        // 当通知发出时，我们认为文件选择状态可能已更改
        // 实际的文件选择状态将由 FilePreviewView 自行判断
        isFileSelected.toggle()
    }

    // MARK: - UI Contributions

    /// Add middle view for Agent mode - 显示文件预览
    /// - Returns: FilePreviewView to be added to the middle column (only when file is selected)
    @MainActor func addMiddleView() -> AnyView? {
        // 始终返回文件预览视图，由 FilePreviewView 自行判断是否显示内容
        if Self.verbose {
            os_log("\(self.t) 提供 FilePreviewView")
        }
        return AnyView(FilePreviewView())
    }
}
