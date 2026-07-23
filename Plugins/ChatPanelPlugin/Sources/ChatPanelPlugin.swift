import LumiKernel
import LumiUI
import SwiftUI

/// Chat Panel 插件
///
/// 注册 Chat 视图容器的 ActivityBar 图标。
/// 当图标激活时，通过 `onContainerActivated` 调整工作区状态：
/// 显示 Rail、不需要 main content 区域、显示 Chat。
@MainActor
public final class ChatPanelPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.chat-panel"
    public let name = "Chat"
    public let order = 78
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {}


    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "bubble.left.and.bubble.right.fill"
            )
        ]
    }

    // MARK: - Status Bar

    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] {
        // Read tools from kernel.toolManager (AgentToolService)
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
                    ChatAvailableToolsDetailView(
                        groups: groups,
                        pluginDisplayNames: pluginNames,
                        totalToolCount: totalTools
                    )
                }
            )
        ]
    }

    // MARK: - Workspace State

    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility {
        // Chat 容器始终显示 activity bar + rail + chat，不需要 main content
        WorkspaceVisibility(
            rail: true,
            chat: true,
            content: false,
            activityBar: true,
            panel: false
        )
    }

    public func onContainerActivated(kernel: LumiKernel, containerID: String) {
        guard containerID == id else { return }
        kernel.workspaceState?.applyVisibility(
            rail: true,
            chat: true,
            content: false,
            activityBar: true,
            panel: false
        )
    }


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
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}

// MARK: - Status Bar Views

private struct ChatAvailableToolsDetailView: View {
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
                            ChatAvailableToolsGroupView(
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

    /// Resolve a plugin id to a human-friendly display name.
    private func displayName(for pluginID: String) -> String {
        pluginDisplayNames[pluginID] ?? pluginID
    }
}

/// A plugin's tool group: a compact header followed by its tool rows.
private struct ChatAvailableToolsGroupView: View {
    @LumiTheme private var theme
    let title: String
    let toolCount: Int
    let tools: [any LumiAgentTool]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Group header: plugin name + tool count, aligned with AppListRow padding.
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
