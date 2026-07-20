import Foundation
import LumiKernel
import SuperLogKit
import os

/// Conversation Manager Plugin
///
/// Implements ConversationManaging protocol using JSON file storage.
/// Data is stored in:
/// <Application Support>/com.coffic.lumi/plugin_data/Conversations/conversations.json
@MainActor
public final class ConversationManagerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-manager")
    nonisolated public static let emoji = "💬"
    public static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.conversation-manager"
    public let name = "Conversation Manager"
    public let order = 61
public static let policy: LumiPluginPolicy = .disabled  // After ChatKernelPlugin

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        guard let storage = kernel.storage else {
            Self.logger.error("\(Self.t)Storage service not available")
            return
        }

        // Use dedicated plugin storage directory (like ProjectsStore)
        let conversationsDirectory = storage.pluginDataDirectory(for: "Conversations")

        do {
            let service = try ConversationService(storageDirectory: conversationsDirectory)
            kernel.registerConversations(service)
            Self.logger.info("\(Self.t)已注册 ConversationManager, 数据目录: \(conversationsDirectory.path)")
        } catch {
            Self.logger.error("\(Self.t)初始化 ConversationService 失败: \(error)")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // No additional boot logic needed
    }
}
