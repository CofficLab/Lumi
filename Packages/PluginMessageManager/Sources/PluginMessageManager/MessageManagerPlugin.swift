import Foundation
import KernelCore
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderStorage
import SuperLogKit

/// Message Manager Plugin (v2)
///
/// 复刻自旧版 `MessageManagerPlugin`：以 SwiftData 持久化的 `MessageManager`
/// 替代 FactoryLumi2 默认的内存版 `DefaultMessageManaging`。
///
/// 装配方式（对齐 `ConversationManagerPlugin`）：
/// - `onBoot` 中创建 `MessageStore` + `MessageManager`，先
///   `unregisterProvider` 再 `registerProvider((any MessageManaging).self)`
///   替换默认实现 —— 必须早于消费方插件（`AgentLoop` 回合写消息、
///   `MessageSender` 发送、`MessageList` 渲染，order 均 > 10）的 `onBoot`，
///   本插件 order=8（紧随 ConversationManagerPlugin order=7）。
/// - 写路径采用 write-behind + read-your-writes：user/error 立即落盘，
///   assistant/tool 后台串行落盘，status 纯内存不落盘。
///
/// 容错：数据库初始化失败时不替换默认实现（保留内存版），仅记日志，不阻塞内核启动。
@MainActor
public final class MessageManagerPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-manager")
    public nonisolated static let emoji = "💬"
    public static let verbose = true

    public let id = "com.coffic.lumi.plugin.message-store"
    public let order = 8

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.message-store",
        name: "Message Manager",
        description: "SwiftData 持久化消息管理（write-behind），替代默认内存实现",
        category: .chat,
        stage: .preview,
        policy: .enabledByDefault
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 1. 计算数据库目录（遵循 Storage 约定：<数据根目录>/MessageManagerPlugin）。
        let storage = kernel.resolveProvider((any StorageProviding).self)
        let databaseRootURL = storage?.pluginDataDirectory(for: "MessageManagerPlugin")
            ?? MessageStore.defaultDatabaseRootURL

        // 2. 创建 SwiftData store；失败时保留默认内存实现，不阻塞内核启动。
        guard let store = try? MessageStore(databaseRootURL: databaseRootURL) else {
            Self.logger.error("\(Self.t)MessageStore 初始化失败，保留默认内存实现")
            return
        }

        // 3. 创建 manager 并替换默认的 MessageManaging。
        let manager = MessageManager(
            store: store,
            dataDirectory: databaseRootURL,
            conversations: kernel.resolveProvider((any ConversationManaging).self)
        )
        kernel.unregisterProvider((any MessageManaging).self)
        try kernel.registerProvider((any MessageManaging).self, manager, forwardsObjectWillChange: false)

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 SwiftData MessageManager，数据库路径：\(databaseRootURL.path)")
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 恢复默认内存实现？不：进程退出，无需恢复。
    }
}
