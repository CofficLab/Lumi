import Foundation
import SwiftUI
import os

/// 磁盘日志插件：通过 OSLogStore 轮询收集日志并写入磁盘文件
///
/// 将原有 `FileLogCoordinator` 的生命周期管理纳入插件系统，
/// 在插件启用时启动日志收集，禁用时停止并 flush。
///
/// ## 特性
///
/// - 单文件大小上限 5 MB，超限自动轮转
/// - 过期日志自动清理（7 天）
/// - 每 2 秒轮询 OSLogStore
/// - Debug / Release 环境隔离
///
/// ## 设计
///
/// ```text
/// os.Logger → 系统统一日志
///         │
///         ▼
/// FileLogCoordinator（OSLogStore 轮询）
///         │
///         ▼
/// ~/Library/Application Support/com.coffic.Lumi/logs_debug_v1/
///   ├── 2026-05-02_10-36-00.log
///   └── ...
/// ```
actor FileLogPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-log")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "📋"
    static var category: PluginCategory { .system }
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id: String = "FileLog"
    static let navigationId: String? = nil
    static let displayName: String = "File Log"
    static let description: String = "Collect OSLog entries to disk files with auto-rotation and cleanup"
    static let iconName: String = "doc.text.below.ecg"
    static let isConfigurable: Bool = false
    static var order: Int { 1 }  // 核心系统服务，需尽早启动

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = FileLogPlugin()

    // MARK: - Lifecycle

    nonisolated func onEnable() {
        FileLogCoordinator.shared.start()
    }

    nonisolated func onDisable() {
        FileLogCoordinator.shared.stop()
    }
}
