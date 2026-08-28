import Foundation
import KernelCore
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import ProviderProject
import ProviderSettingView
import ProviderStorage
import ProviderToolManager
import KitSuperLog
import SwiftUI

/// Conversation Manager Plugin
@MainActor
public final class ConversationManagerPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-manager")
    public nonisolated static let emoji = "💬"
    public static let verbose = false

    public let id = "com.coffic.lumi.plugin.conversation-store"
    public let order = 7

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-store",
        name: "Conversation Manager",
        description: "SwiftData 持久化对话管理，替代默认内存实现",
        category: .chat,
        stage: .preview,
        policy: .required
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 1. 计算数据库目录（遵循 Storage 约定：<数据根目录>/ConversationStore）。
        let storage = kernel.resolveProvider((any StorageProviding).self)
        let databaseRootURL = storage?.pluginDataDirectory(for: "ConversationStore")
            ?? ConversationStore.defaultDatabaseRootURL

        // 2. 创建 SwiftData store；失败时保留默认内存实现，不阻塞内核启动。
        guard let store = try? ConversationStore(databaseRootURL: databaseRootURL) else {
            Self.logger.error("\(Self.t)ConversationStore 初始化失败，保留默认内存实现")
            return
        }

        // 3. 创建 manager 并替换默认的 ConversationManaging。
        let manager = ConversationManager(
            store: store,
            dataDirectory: databaseRootURL,
            project: kernel.resolveProvider((any ProjectProviding).self),
            llmProviderManager: kernel.resolveProvider((any LLMManaging).self),
            messageManager: kernel.resolveProvider((any MessageManaging).self),
            toolManager: kernel.resolveProvider((any ToolManagerProviding).self),
            agentTurn: kernel.resolveProvider((any AgentLoopProviding).self),
            eventBus: KernelCoreEventBus()
        )
        let previousManager = kernel.resolveProvider((any ConversationManaging).self)
        kernel.unregisterProvider((any ConversationManaging).self)
        try kernel.registerProvider((any ConversationManaging).self, manager)
        previousManager?.transferObservers(to: manager)

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 SwiftData ConversationManager，数据库路径：\(databaseRootURL.path)")
        }

        // 4. 注册「Conversations」设置入口。
        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([
            SettingEntryItem(
                id: "\(id).settings",
                title: LumiPluginLocalization.string("Conversations", bundle: .module),
                systemImage: "bubble.left.and.bubble.right",
                order: 7
            ) { [weak manager] in
                ConversationStoreSettingsView(manager: manager)
            },
        ])

        // 5. 后台启动 v4 历史会话迁移（不 await，onBoot 立即返回）。
        //    迁移完成后装载会话列表（此时新库已含历史会话）。
        let progress = ConversationMigrationProgressStore.shared
        let migration = ConversationLegacyMigration(
            reader: V4ConversationReader(
                v4DataRootDirectory: V4DataDirectoryLocator.locate(
                    currentDataRootDirectory: storage?.dataRootDirectory ?? databaseRootURL
                )
            ),
            store: store,
            progress: progress,
            destinationRootURL: databaseRootURL
        )
        Task { @MainActor in
            await migration.run()
            manager.loadConversations()
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // Provider（ConversationManaging）由内核按插件归属自动移除；
        // 这里只撤回设置入口。若宿主希望回退到内存实现，可在此重建注册。
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(
            ids: ["\(id).settings"]
        )
    }
}
