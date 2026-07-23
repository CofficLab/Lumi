import LumiKernel
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

    public func onBoot(kernel: LumiKernel) throws {}

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
        let tools = kernel.toolManager?.allAgentTools() ?? []
        return [
            StatusBarItem(
                id: "\(id).tools",
                title: "Available Tools",
                systemImage: "wrench.and.screwdriver",
                placement: .trailing,
                popover: {
                    ChatAvailableToolsDetailView(tools: tools)
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

    public func boot(kernel: LumiKernel) async throws {}

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func sendMiddlewares(kernel: LumiKernel) -> [any LumiSendMiddleware] { [] }
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
    let tools: [any LumiAgentTool]

    var body: some View {
        StatusBarPopoverScaffold(
            title: "Available Tools",
            systemImage: "wrench.and.screwdriver",
            subtitle: "\(tools.count) tools",
            headerAccessory: { EmptyView() },
            content: {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(tools, id: \.name) { tool in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tool.name)
                                    .font(.appMonoCaption)
                                Text(tool.toolDescription)
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                                    .lineLimit(2)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            Divider()
                        }
                    }
                }
                .frame(minHeight: 280, maxHeight: 420)
            },
            footer: { EmptyView() }
        )
    }
}
