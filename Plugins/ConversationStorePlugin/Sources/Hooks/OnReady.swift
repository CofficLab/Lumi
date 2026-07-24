import Foundation
import LumiKernel
import SuperLogKit
import os

/// ConversationStore 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑:注册 ConversationManager、初始化 ConversationStore、
/// 迁移 v4 历史会话、装载会话列表。**迁移以后台任务方式启动**,不阻塞 onReady 串行链。
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

            // 后台启动 v4 历史会话迁移(不 await,立即返回,onReady 不阻塞)
            // 注:`LegacyDataProviding` 是 @MainActor,读 v4 库在主线程;
            // `store` 是 actor,写库会 hop 到 actor,不阻塞主线程。
            let progress = ConversationMigrationProgressStore.shared
            let migration = ConversationLegacyMigration(kernel: kernel, store: store, progress: progress)
            let itemID = "com.coffic.lumi.plugin.conversation-store.migration.status"
            Task { @MainActor in
                await migration.run()
                // 迁移完成后:装载会话到 manager(此时新库已含历史会话)+ 移除状态栏项
                if let manager = kernel.conversations as? ConversationManager {
                    manager.loadConversations()
                }
                if !progress.isActive {
                    kernel.sharedUI?.unregisterStatusBarItem(id: itemID)
                }
            }

            if Self.verbose {
                Self.logger.info("ConversationStorePlugin 启动完成，数据库路径: \(databaseRootURL.path)")
            }
        } catch {
            throw ConversationStoreError.initializationFailed("ConversationStorePlugin 数据库初始化失败: \(error.localizedDescription)")
        }
    }
}
