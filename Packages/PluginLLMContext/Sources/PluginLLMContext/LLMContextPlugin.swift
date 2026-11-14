import Foundation
import KernelCore
import KitAgentTool
import LumiLoggingKit
import os
import ProviderChatSection
import ProviderConversation
import ProviderLifecycleHooks
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import ProviderStorage
import ProviderToolManager

/// 为 App 提供 LLM 上下文准备能力的独立插件。
@MainActor
public final class LLMContextPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.llm-context",
        category: "LLMContextPlugin"
    )
    public nonisolated static let emoji = "🧠"
    public let id = "com.coffic.lumi.plugin.llm-context"
    public let order = 8
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.llm-context",
        name: "LLM Context",
        description: "Prepares bounded LLM context and refreshes summaries in the background.",
        category: .chat,
        stage: .preview,
        policy: .alwaysOn
    )

    private var provider: LLMContextProvider?
    private let toolbarState = ContextToolbarState()
    private var toolbarObserver: ContextToolbarObserver?
    /// `turnFinished` 钩子（见 `Hooks/LLMContextTurnFinishedHook.swift`）。
    private var turnFinishedHook: LLMContextTurnFinishedHook?
    /// 会话删除时清理压缩块、旧摘要与幕后用量（#350）。
    private var deletionObserver: LLMContextConversationDeletionObserver?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let messages = kernel.resolveProvider((any MessageManaging).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let llmProvider = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("\(Self.t)上下文插件缺少消息、会话或 LLM Provider，跳过启动")
            return
        }

        let summaryStore: ContextSummaryStore?
        let blockStore: CompressionBlockStore?
        let auxiliaryStore: AuxiliaryUsageStore?
        let decompressionDirectory: URL?
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let directory = storage.pluginDataDirectory(for: id)
            summaryStore = try? ContextSummaryStore(directory: directory)
            if summaryStore == nil {
                Self.logger.error("\(Self.t)上下文摘要数据库初始化失败，改用内存摘要")
            }
            blockStore = try? CompressionBlockStore(directory: directory)
            if blockStore == nil {
                Self.logger.error("\(Self.t)压缩块数据库初始化失败，改用内存块")
            }
            auxiliaryStore = try? AuxiliaryUsageStore(directory: directory)
            if auxiliaryStore == nil {
                Self.logger.error("\(Self.t)幕后用量数据库初始化失败，改用内存账本")
            }
            decompressionDirectory = directory.appendingPathComponent("decompressed", isDirectory: true)
        } else {
            summaryStore = nil
            blockStore = nil
            auxiliaryStore = nil
            decompressionDirectory = nil
            Self.logger.error("\(Self.t)缺少 StorageProviding，摘要、压缩块与幕后用量不会持久化")
        }

        let auxiliaryLedger = AuxiliaryUsageLedger(store: auxiliaryStore)
        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llmProvider,
            summaryStore: summaryStore,
            blockStore: blockStore,
            auxiliaryUsage: auxiliaryLedger
        )
        self.provider = provider

        toolbarObserver?.cancel()
        toolbarObserver = ContextToolbarObserver(
            conversations: conversations,
            messages: messages,
            llmManager: llmProvider,
            onConversationChange: { [weak toolbarState] id in
                toolbarState?.setSelectedConversationID(id)
            },
            onMessageInsert: { [weak toolbarState] conversationID in
                guard conversationID == toolbarState?.selectedConversationID else { return }
                toolbarState?.markMessagesChanged(conversationID: conversationID)
            },
            onLLMChange: { [weak toolbarState] in
                toolbarState?.markLLMChanged()
            }
        )

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).context-toolbar-button",
                order: 85,
                placement: .toolbarLeading
            ) {
                ContextToolbarView(
                    provider: provider,
                    messages: messages,
                    state: self.toolbarState
                )
            },
        ])

        kernel.unregisterProvider((any LLMContextProviding).self)
        try kernel.registerProvider((any LLMContextProviding).self, provider)

        kernel.unregisterProvider((any LLMAuxiliaryUsageProviding).self)
        try kernel.registerProvider((any LLMAuxiliaryUsageProviding).self, auxiliaryLedger)

        let hook = LLMContextTurnFinishedHook(provider: provider)
        turnFinishedHook = hook
        kernel.resolveProvider((any LifecycleHooksProviding).self)?
            .addTurnFinishedHook { [weak hook] context in
                hook?.apply(to: context)
            }

        registerRecoveryTools(
            kernel: kernel,
            provider: provider,
            directory: decompressionDirectory
        )

        deletionObserver?.cancel()
        deletionObserver = LLMContextConversationDeletionObserver(conversations: conversations) {
            [weak provider, weak auxiliaryLedger] conversationID in
            await provider?.purgeConversation(conversationID)
            await auxiliaryLedger?.remove(conversationID: conversationID)
        }
    }

    /// 注册上下文恢复工具（#1160 Phase C）：组成报告、搜索、按块解压。
    ///
    /// 缺少 ToolManagerProviding 时只记录日志、跳过注册——上下文压缩本身仍工作，
    /// 恢复工具是可选增强，不应阻塞插件启动。
    private func registerRecoveryTools(
        kernel: KernelCoreContainer,
        provider: LLMContextProvider,
        directory: URL?
    ) {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)缺少 ToolManagerProviding，上下文恢复工具未注册")
            return
        }
        toolManager.add(ContextStatusTool(provider: provider), pluginID: id)
        toolManager.add(SearchContextTool(provider: provider), pluginID: id)
        toolManager.add(
            DecompressContextTool(provider: provider, directory: directory),
            pluginID: id
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        toolbarObserver?.cancel()
        toolbarObserver = nil
        deletionObserver?.cancel()
        deletionObserver = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).context-toolbar-button")
        let toolManager = kernel.resolveProvider((any ToolManagerProviding).self)
        toolManager?.remove(id: ContextStatusTool.toolName)
        toolManager?.remove(id: SearchContextTool.toolName)
        toolManager?.remove(id: DecompressContextTool.toolName)
        turnFinishedHook = nil
        provider?.shutdown()
        provider = nil
        kernel.unregisterProvider((any LLMContextProviding).self)
        kernel.unregisterProvider((any LLMAuxiliaryUsageProviding).self)
    }
}
