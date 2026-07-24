import Foundation
import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// 工具管理插件
///
/// 向 LumiKernel 注册 ToolManager 服务,并注册 5 个核心工具:
/// ListDirectoryTool, ReadFileTool, WriteFileTool, EditFileTool, ShellTool.
@MainActor
public final class ToolManagerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.tool-manager")
    public nonisolated static let emoji = "🔧"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.tool-manager"
    public let name = "ToolManager Plugin"
    public let order = 30
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        let toolManagerService = ToolManagerService()
        kernel.registerToolManagerService(toolManagerService)

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 ToolManager 服务")
        }
    }

    public func onReady(kernel: LumiKernel) async throws {}

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        [
            ListDirectoryTool(),
            ReadFileTool(),
            WriteFileTool(),
            EditFileTool(),
            ShellTool(),
        ]
    }

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] {
        let toolManager = kernel.toolManager
        let groups = toolManager?.agentToolsGroupedByPlugin() ?? []
        var pluginNames: [String: String] = [:]
        for plugin in kernel.pluginManager.allPlugins {
            pluginNames[plugin.id] = plugin.name
        }
        let totalTools = toolManager?.allAgentTools().count ?? 0
        return [
            StatusBarItem(
                id: "\(id).tools",
                title: "Available Tools",
                systemImage: "wrench.and.screwdriver",
                placement: .trailing,
                popover: {
                    ToolManagerAvailableToolsDetailView(
                        groups: groups,
                        pluginDisplayNames: pluginNames,
                        totalToolCount: totalTools
                    )
                }
            ),
        ]
    }

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
        let toolManager = kernel.toolManager
        let groups = toolManager?.agentToolsGroupedByPlugin() ?? []
        var pluginNames: [String: String] = [:]
        for plugin in kernel.pluginManager.allPlugins {
            pluginNames[plugin.id] = plugin.name
        }
        return [
            SettingsTabItem(
                id: "\(id).tools",
                title: "Tools",
                systemImage: "wrench.and.screwdriver",
                order: 50
            ) {
                ToolManagerSettingsView(
                    groups: groups,
                    pluginDisplayNames: pluginNames
                )
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
