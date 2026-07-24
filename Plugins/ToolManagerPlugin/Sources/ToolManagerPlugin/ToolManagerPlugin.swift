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

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.tool-manager"
    public let name = "ToolManager Plugin"
    public let order = 30
    public let policy: LumiPluginPolicy = .alwaysOn

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onBoot(kernel: LumiKernel) async throws {
        let toolManagerService = ToolManagerService()
        kernel.registerToolManagerService(toolManagerService)

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 ToolManager 服务")
        }

        // Register 5 core tools
        toolManagerService.add(ListDirectoryTool(), pluginID: id)
        toolManagerService.add(ReadFileTool(), pluginID: id)
        toolManagerService.add(WriteFileTool(), pluginID: id)
        toolManagerService.add(EditFileTool(), pluginID: id)
        toolManagerService.add(ShellTool(), pluginID: id)
    }

    public func onReady(kernel: LumiKernel) async throws {}


    // MARK: - LumiPlugin stubs

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
    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility { WorkspaceVisibility() }
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}

// MARK: - Status Bar Views

private struct ToolManagerAvailableToolsDetailView: View {
    @LumiTheme private var theme
    let groups: [(pluginID: String, tools: [any LumiAgentTool])]
    let pluginDisplayNames: [String: String]
    let totalToolCount: Int

    var body: some View {
        StatusBarPopoverScaffold(
            title: "Available Tools",
            systemImage: "wrench.and.screwdriver",
            subtitle: "\(totalToolCount) tools · \(groups.count) plugins"
        ) {
            if groups.isEmpty {
                AppEmptyState(
                    icon: "wrench.and.screwdriver",
                    title: "No tools available"
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(groups.enumerated()), id: \.element.pluginID) { _, group in
                            ToolManagerAvailableToolsGroupView(
                                title: displayName(for: group.pluginID),
                                toolCount: group.tools.count,
                                tools: group.tools
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(minHeight: 220, maxHeight: 420)
            }
        }
        .appThemedAppearance()
    }

    private func displayName(for pluginID: String) -> String {
        pluginDisplayNames[pluginID] ?? pluginID
    }
}

private struct ToolManagerAvailableToolsGroupView: View {
    @LumiTheme private var theme
    let title: String
    let toolCount: Int
    let tools: [any LumiAgentTool]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textSecondary)
                    .textCase(.uppercase)
                Spacer(minLength: 0)
                Text("\(toolCount)")
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.horizontal, 16)

            LazyVStack(spacing: 4) {
                ForEach(tools, id: \.name) { tool in
                    AppListRow {
                        HStack(spacing: 10) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.appCaptionEmphasized)
                                .foregroundColor(theme.textSecondary)
                                .frame(width: 20, height: 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(theme.textTertiary.opacity(0.12))
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tool.name)
                                    .font(.appCaptionEmphasized)
                                    .foregroundColor(theme.textPrimary)
                                Text(tool.toolDescription)
                                    .font(.appMicro)
                                    .foregroundColor(theme.textSecondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }
}
