import Foundation
import os
import KernelCore
import ProviderSettingView
import ProviderStorage
import ProviderToolManager
import SuperLogKit
import SwiftUI

/// 工具管理插件（KernelCore 生态）。
///
/// 复刻旧版 `ToolManagerPlugin` 的完整体验：
/// - 以自研 `ToolManagerService` 替换 `ProviderFactory` 预注册的默认
///   `ToolManagerProviding`，注册 7 个内置文件/终端工具；
/// - 工具调用记录存储**复用旧版同一数据库目录**
///   （`StorageProviding.pluginDataDirectory(for: "ToolManager")`，
///   数据库文件 `tool_calls.sqlite`），无损恢复旧数据；
/// - 设置界面注入「Tools」入口（可用工具 / 执行日志 / 使用统计）。
///
/// 执行顺序：order = 6（先于 `PluginAgentLoop` order=8，确保 Agent 回合
/// 循环执行 `toolManager?.allTools()` 时内置工具已就绪；后于
/// `PluginLLMManager` order=5）。
@MainActor
public final class PluginToolManager: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.tool-manager", category: "Plugin")
    nonisolated public static let emoji = "🔧"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.tool-manager"
    public let order = 6

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Tool Manager",
            description: "内置文件/终端工具 + 工具调用记录（复刻旧版体验，数据目录一致）",
            category: .chat,
            stage: .preview,
            policy: .required
        )
    }

    /// 本插件装配的 ToolManager 实现（设置视图读取）。
    private var service: ToolManagerService?

    /// 设置页入口 id（onShutdown 时撤回）。
    private let settingsEntryID = "com.coffic.lumi.plugin.tool-manager.tools"

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let service = ToolManagerService()
        self.service = service

        // 1. 复用旧实例的记录存储：与旧版同一数据库目录（tool_calls.sqlite），
        //    避免两个 SwiftData 容器打开同一文件；旧实例由 ProviderFactory 预注册。
        if let previous = kernel.resolveProvider((any ToolManagerProviding).self) as? DefaultToolManagerProviding,
           let store = previous.recordStore {
            service.recordStore = store
            if Self.verbose {
                Self.logger.info("\(Self.t)reusing existing record store at \(store.directory.path)")
            }
        } else if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let databaseRootURL = storage.pluginDataDirectory(for: "ToolManager")
            let store = ProviderToolManager.ToolCallRecordStore(databaseRootURL: databaseRootURL)
            service.recordStore = store
            if Self.verbose {
                Self.logger.info("\(Self.t)created record store at \(databaseRootURL.path)")
            }
        }

        // 2. 注册内置工具（与旧版 Tools 目录一致）。
        service.registerBuiltinTools()

        // 3. 替换默认 ToolManagerProviding 实现。
        kernel.unregisterProvider((any ToolManagerProviding).self)
        try kernel.registerProvider((any ToolManagerProviding).self, service, forwardsObjectWillChange: false)

        // 4. 设置界面注入「Tools」入口（复刻旧版 settingsTabItems）。
        if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
            settings.addEntries([
                SettingEntryItem(
                    id: settingsEntryID,
                    title: "Tools",
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
        if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
            settings.removeEntries(ids: [settingsEntryID])
        }
        service = nil
        // 内核会按插件归属自动撤回 onBoot 注册的 Provider。
    }
}
