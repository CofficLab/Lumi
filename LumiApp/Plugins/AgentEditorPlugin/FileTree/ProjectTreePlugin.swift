import Foundation
import os
import MagicKit

/// 文件树模块：提供 logger 和插件配置常量
///
/// 已合并到 EditorPlugin 中，不再作为独立插件注册。
enum FileTreeModule {
    /// 日志专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree")

    /// 日志详细程度控制
    nonisolated static let verbose: Bool = false
}
