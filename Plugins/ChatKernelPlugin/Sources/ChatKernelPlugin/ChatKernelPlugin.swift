import Foundation
import LumiKernel
import os
import SuperLogKit

/// 聊天插件
///
/// 向 LumiKernel 注册 Chat 服务。
@MainActor
public final class ChatKernelPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat")
    public nonisolated static let emoji = "💬"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.chat"
    public let name = "Chat Plugin"
    public let order = 60
    public static let policy: LumiPluginPolicy = .disabled // 核心插件

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onReady(kernel: LumiKernel) throws {
        let chatService = ChatService()
        kernel.registerChat(chatService)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Chat 服务")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // 无需额外启动逻辑
    }
}
