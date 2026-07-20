import Foundation
import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// Clipboard Manager 内核插件
///
/// 向 LumiKernel 注册剪贴板管理相关的功能：
/// - ViewContainer：剪贴板历史视图
@MainActor
public final class ClipboardManagerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.clipboard-manager")
    nonisolated public static let emoji = "📋"
    nonisolated public static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.clipboard-manager"
    public let name = "Clipboard Manager Plugin"
    public let order = 70  // 功能插件

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // 注册视图容器（order 自动从插件继承）
        kernel.viewContainer?.register(
            ViewContainerItem(
                id: id,
                title: "Clipboard",
                systemImage: "doc.on.clipboard"
            ) {
                ClipboardHistoryView()
            }
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Clipboard Manager 视图容器到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // 启动剪贴板监控
        ClipboardMonitor.shared.startMonitoring()

        if Self.verbose {
            Self.logger.info("\(Self.t)Clipboard Manager 插件启动完成")
        }
    }
}