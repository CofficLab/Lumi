import Foundation
import LumiKernel
import SuperLogKit
import os

/// ConversationStore 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑:注册 ConversationManager、初始化 ConversationStore、
/// 迁移 v4 历史会话、装载会话列表。
@MainActor
public struct ConversationStoreOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-store")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) async throws {
        let manager = ConversationManager(kernel: kernel)
        kernel.registerConversations(manager)

        if Self.verbose {
            Self.logger.info("已注册 ConversationManager")
        }

        // Initialize ConversationStore with proper database root URL
        let databaseRootURL: URL
        let dataDirectory: URL

        if let storage = kernel.storage {
            databaseRootURL = storage.dataRootDirectory
            dataDirectory = storage.dataRootDirectory
        } else {
            databaseRootURL = ConversationStore.defaultDatabaseRootURL
            dataDirectory = ConversationStore.defaultDatabaseRootURL
        }

        do {
            let store = try ConversationStore(databaseRootURL: databaseRootURL)
            ConversationManagerRuntimeBridge.shared.store = store
            ConversationManagerRuntimeBridge.shared.dataDirectory = dataDirectory

            // 迁移 v4 历史会话(必须在 loadConversations 之前完成,幂等 + 吞错)
            await ConversationLegacyMigration(kernel: kernel, store: store).run()

            // Load conversations into the manager
            if let manager = kernel.conversations as? ConversationManager {
                manager.loadConversations()
            }

            if Self.verbose {
                Self.logger.info("ConversationStorePlugin 启动完成，数据库路径: \(databaseRootURL.path)")
            }
        } catch {
            throw ConversationStoreError.initializationFailed("ConversationStorePlugin 数据库初始化失败: \(error.localizedDescription)")
        }
    }
}
