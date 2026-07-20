import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 聊天分区插件
///
/// 提供 ChatSectionProviding 服务的默认实现。
/// 负责管理所有插件的聊天分区项、工具栏、标题项的注册、排序和查询。
@MainActor
public final class ChatSectionPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chatsection")
    nonisolated public static let emoji = "💬"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.chatsection"
    public let name = "ChatSection Plugin"
    public let order = 17
public static let policy: LumiPluginPolicy = .disabled  // 核心插件，优先注册

    // MARK: - State

    private var chatSectionService: DefaultChatSectionProviding?

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // 1. 注册 ChatSectionService（内核服务）
        let chatSectionServiceInstance = DefaultChatSectionProviding()
        kernel.registerChatSectionService(chatSectionServiceInstance)
        self.chatSectionService = chatSectionServiceInstance

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 ChatSection 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)ChatSection 插件启动完成")
        }
    }
}
