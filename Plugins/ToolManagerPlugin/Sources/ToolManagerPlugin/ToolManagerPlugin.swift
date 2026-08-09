import Foundation
import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// 工具管理插件
///
/// 向 LumiKernel 注册 ToolManager 服务,并注册文件/终端工具及内置子代理工具。
@MainActor
public final class ToolManagerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.tool-manager")
    public nonisolated static let emoji = "🔧"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.tool-manager"
    public var name: String {
        LumiPluginLocalization.string("ToolManager Plugin", bundle: .module)
    }
    public let order = 30
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    /// 设置页「执行日志」Tab 需要的 store 引用,由 onBoot 阶段持有,
    /// 在 settingsTabItems 里透传给对应的 SwiftUI 视图。
    private var toolCallRecordStore: ToolCallRecordStore?

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        let toolManagerService = ToolManagerService()
        toolManagerService.kernel = kernel

        // 初始化工具调用记录存储(后台异步写入，不影响主流程)
        // 存储目录: kernel.storage.pluginDataDirectory(for: "ToolManager")
        if let storage = kernel.storage {
            let databaseRootURL = storage.pluginDataDirectory(for: "ToolManager")
            let store = ToolCallRecordStore(databaseRootURL: databaseRootURL)
            // 启动后台定时刷新任务
            await store.startFlushTask()
            toolManagerService.recordStore = store
            self.toolCallRecordStore = store
        }

        try kernel.registerToolManagerService(toolManagerService)

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 ToolManager 服务")
        }
    }

    public func onReady(kernel: LumiKernel) async throws {}

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        [
            ListDirectoryTool(),
            GlobTool(),
            ReadImageTool(),
            ReadFileTool(),
            WriteFileTool(),
            EditFileTool(),
            ShellTool(),
            SubAgentTool(),
        ]
    }

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] {
        return []
    }

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
        let store = toolCallRecordStore
        return [
            SettingsTabItem(
                id: "\(id).tools",
                title: LumiPluginLocalization.string("Tools", bundle: .module),
                systemImage: "wrench.and.screwdriver",
                order: 6
            ) {
                ToolManagerSettingsView(kernel: kernel, toolCallRecordStore: store)
            },
        ]
    }

    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
