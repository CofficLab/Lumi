import Foundation
import KernelCore
import KitAgentTool
import os
import ProviderConversation
import ProviderProject
import ProviderSettingView
import ProviderStorage
import ProviderToolManager
import ProviderAgentLoop
import LumiLoggingKit
import SwiftUI

/// 工具管理插件。
@MainActor
public final class PluginToolManager: SuperPlugin, PluginDataMigrating, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.tool-manager", category: "Plugin")
    public nonisolated static let emoji = "🔧"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.tool-manager"
    public let legacyDataDirectoryNames = ["ToolManager"]
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
    private var agentLoopToolCallsObserver: ToolCallsObserver?

    /// 后台任务登记表：跨回合存活的进程由它管理，不走 ToolJob 事件通道。
    private var backgroundTaskRegistry: BackgroundTaskRegistry?

    /// 设置页入口 id（onShutdown 时撤回）。
    private let settingsEntryID = "com.coffic.lumi.plugin.tool-manager.tools"

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let service = ToolManager()
        self.service = service

        // 1. 初始化插件自己的调用记录存储。
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let databaseRootURL = storage.pluginDataDirectory(for: id)
            let store = ProviderToolManager.ToolCallRecordStore(databaseRootURL: databaseRootURL)
            service.recordStore = store
            if Self.verbose {
                Self.logger.info("\(Self.t)created record store at \(databaseRootURL.path)")
            }

            let jobStore = ProviderToolManager.ToolJobRecordStore(databaseRootURL: databaseRootURL)
            service.jobRecordStore = jobStore
            if Self.verbose {
                let jobStoreURL = jobStore.directory.appendingPathComponent("tool_jobs.sqlite")
                Self.logger.info("\(Self.t)created job store at \(jobStoreURL.path)")
            }

            // 后台任务的输出文件与状态都落在插件自己的数据目录里。
            let registry = BackgroundTaskRegistry(rootDirectory: databaseRootURL)
            service.backgroundTaskRegistry = registry
            self.backgroundTaskRegistry = registry
            if Self.verbose {
                Self.logger.info("\(Self.t)created background task registry at \(databaseRootURL.path)")
            }
        }

        // 2. 注册内置工具。
        let project = kernel.resolveProvider((any ProjectProviding).self)
        service.registerBuiltinTools(workspaceRootProvider: { [weak project] in
            project?.workspaceRoot
        })

        // 3. 替换默认 ToolManagerProviding 实现。
        kernel.unregisterProvider((any ToolManagerProviding).self)
        try kernel.registerProvider((any ToolManagerProviding).self, service)

        // 4. 设置界面注入「Tools」入口。
        if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
            settings.addEntries([
                SettingEntryItem(
                    id: settingsEntryID,
                    title: pluginLocalization.string("Tools"),
                    systemImage: "wrench.and.screwdriver",
                    order: 6
                ) { [weak service] in
                    if let service {
                        let capability = ToolManagerCapabilityAdapter(
                            manager: service,
                            store: service.recordStore
                        )
                        let viewModel = ToolManagerViewModel(capability: capability)
                        ToolManagerSettingsView(viewModel: viewModel)
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
        agentLoopToolCallsObserver?.cancel()
        agentLoopToolCallsObserver = nil
        if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
            settings.removeEntries(ids: [settingsEntryID])
        }
        // 应用退出时终止仍在运行的后台任务，避免留下孤儿进程。
        if let registry = backgroundTaskRegistry {
            Task { [weak self] in
                let stopped = await registry.stopAll()
                if stopped > 0 {
                    Self.logger.info("\(Self.t)stopped \(stopped) background task(s) on shutdown")
                }
                self?.backgroundTaskRegistry = nil
            }
        }
        service = nil
        // 内核会按插件归属自动撤回 onBoot 注册的 Provider。
    }

    /// ToolManager 是工具调用事件的消费者；AgentLoop 只负责发布 LLM 结果。
    public func onReady(kernel: KernelCoreContainer) throws {
        guard let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self),
              let conversationManager = kernel.resolveProvider((any ConversationManaging).self),
              let service else {
            Self.logger.error("\(Self.emoji)无法建立 AgentLoop → ToolManager 事件订阅")
            return
        }
        service.conversationManager = conversationManager

        agentLoopToolCallsObserver = ToolCallsObserver(
            agentLoop: agentLoop,
            conversations: conversationManager,
            service: service
        )
    }
}
