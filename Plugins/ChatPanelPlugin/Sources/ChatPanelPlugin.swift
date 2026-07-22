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
    public static let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onReady(kernel: LumiKernel) throws {}

    public func boot(kernel: LumiKernel) async throws {}

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
        print("ChatPanelPlugin.statusBarItems: kernel.toolManager = \(String(describing: kernel.toolManager)), tools count = \(tools.count)")
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