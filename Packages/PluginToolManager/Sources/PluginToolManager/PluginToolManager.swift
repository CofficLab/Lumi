import Foundation
import KernelCore
import KitAgentTool
import os
import ProviderConversation
import ProviderSettingView
import ProviderStorage
import ProviderToolManager
import ProviderAgentLoop
import KitSuperLog
import SwiftUI

/// 工具管理插件。
@MainActor
public final class PluginToolManager: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.tool-manager", category: "Plugin")
    public nonisolated static let emoji = "🔧"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.tool-manager"
    public let order = 6
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.tool-manager",
        name: "Plugin Tool Manager",
        description: "",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )

    /// 本插件装配的 ToolManager 实现（设置视图读取）。
    private var service: ToolManager?
    private var agentLoopObserver: (any AgentLoopObserverHandle)?

    /// 设置页入口 id（onShutdown 时撤回）。
    private let settingsEntryID = "com.coffic.lumi.plugin.tool-manager.tools"

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let service = ToolManager()
        self.service = service

        // 1. 初始化插件自己的调用记录存储。
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let databaseRootURL = storage.pluginDataDirectory(for: "ToolManager")
            let store = ProviderToolManager.ToolCallRecordStore(databaseRootURL: databaseRootURL)
            service.recordStore = store
            if Self.verbose {
                Self.logger.info("\(Self.t)created record store at \(databaseRootURL.path)")
            }
        }

        // 2. 注册内置工具。
        service.registerBuiltinTools()

        // 3. 替换默认 ToolManagerProviding 实现。
        kernel.unregisterProvider((any ToolManagerProviding).self)
        try kernel.registerProvider((any ToolManagerProviding).self, service, forwardsObjectWillChange: false)

        // 4. 设置界面注入「Tools」入口。
        if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
            settings.addEntries([
                SettingEntryItem(
                    id: settingsEntryID,
                    title: LumiPluginLocalization.string("Tools", bundle: .module),
                    systemImage: "wrench.and.screwdriver",
                    order: 6
                ) { [weak service] in
                    if let service {
                        ToolManagerSettingsView(
                            manager: service,
                            store: service.recordStore
                        )
                    } else {
                        EmptyView()
                    }
                },
            ])
        } else {
            Self.logger.warning("\(Self.t)SettingViewProviding not resolved, settings entry skipped")
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)registered ToolManagerService with \(service.allTools().count) builtin tools")
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        agentLoopObserver?.cancel()
        agentLoopObserver = nil
        if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
            settings.removeEntries(ids: [settingsEntryID])
        }
        service = nil
        // 内核会按插件归属自动撤回 onBoot 注册的 Provider。
    }

    /// ToolManager 是工具调用事件的消费者；AgentLoop 只负责发布 LLM 结果。
    public func onReady(kernel: KernelCoreContainer) throws {
        guard let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let service else {
            Self.logger.error("\(Self.emoji)无法建立 AgentLoop → ToolManager 事件订阅")
            return
        }

        agentLoopObserver = agentLoop.addAgentLoopObserver { [weak self] event in
            guard case let .toolCallsReceived(conversationID, turnID, _, toolCalls) = event else {
                return
            }
            guard !toolCalls.isEmpty else { return }
            let policy: ToolExecutionPolicy
            switch conversations.automationLevel(for: conversationID) {
            case .chat: policy = .blockAll
            case .autonomous: policy = .autoExecute
            case .build: policy = .requireApprovalForHighRisk
            }
            let inputs = toolCalls.map { ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) }
            if Self.verbose {
                Self.logger.info("\(Self.t)收到 AgentLoop 工具调用事件 conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8)), count=\(inputs.count)")
            }
            Task { @MainActor [weak self] in
                guard let self else {
                    Self.logger.error("\(Self.emoji)ToolManager 插件已释放，无法执行工具批次")
                    return
                }
                _ = await service.executeBatch(
                    inputs,
                    policy: policy,
                    conversationID: conversationID,
                    turnID: turnID
                )
            }
        }
    }
}
