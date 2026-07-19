import Foundation
import LumiKernel
import SuperLogKit
import os

/// 编辑器插件
///
/// 向 LumiKernel 注册 Editor 服务。
@MainActor
public final class EditorKernelPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor")
    nonisolated public static let emoji = "📝"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.editor"
    public let name = "Editor Plugin"
    public let order = 50  // 核心插件

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        let editorService = EditorService()
        kernel.registerEditor(editorService)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Editor 服务")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // 无需额外启动逻辑
    }
}