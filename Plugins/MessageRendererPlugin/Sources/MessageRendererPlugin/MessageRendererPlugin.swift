import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class MessageRendererPlugin: LumiPlugin {
    public nonisolated static let baseOrder: Int = 10

    public let id = "CoreMessageRenderer"
    public let name = "核心消息渲染器"
    public let order = 10
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        // 注册 Manager
        kernel.registerMessageRendererManagerService(MessageRendererManager.shared)

        // 注册内置渲染器
        guard let manager = kernel.resolveService(MessageRendererManaging.self) else {
            return
        }

        let base = Self.baseOrder

        // 优先级最高：turn-completed / status 特殊渲染
        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-turn-completed",
                order: base + 320,
                canRender: { message in
                    message.renderKind == "turn-completed" || message.content == LumiChatMarkers.turnCompleted
                },
                render: { message, _ in
                    TurnCompletedMessageView(message: message)
                }
            )
        )

        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-status-message",
                order: base + 310,
                canRender: { message in
                    message.role == .status
                        && message.renderKind != "turn-completed"
                        && message.content != LumiChatMarkers.turnCompleted
                },
                render: { message, _ in
                    StatusMessageView(message: message)
                }
            )
        )

        // 错误消息：让 Provider 特定渲染器优先
        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-error-message",
                order: base + 290,
                canRender: { message in
                    guard message.role == .error || message.isError else { return false }
                    if let renderKind = message.renderKind,
                       ProviderRenderKindManager.shared.isProviderSpecificRenderKind(renderKind) {
                        return false
                    }
                    return true
                },
                render: { message, showRawMessage in
                    ErrorMessageView(message: message, showRawMessage: showRawMessage)
                }
            )
        )

        // 工具结果
        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-tool-message",
                order: base + 240,
                canRender: { message in
                    message.role == .tool
                },
                render: { message, showRawMessage in
                    ToolMessageView(message: message, showRawMessage: showRawMessage)
                }
            )
        )

        // 用户消息
        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-user-message",
                order: base + 190,
                canRender: { message in
                    message.role == .user
                },
                render: { message, showRawMessage in
                    UserMessageView(message: message, showRawMessage: showRawMessage)
                }
            )
        )

        // 助手消息
        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-assistant-message",
                order: base + 180,
                canRender: { message in
                    message.role == .assistant
                },
                render: { message, showRawMessage in
                    AssistantMessageView(message: message, showRawMessage: showRawMessage)
                }
            )
        )

        // 系统消息
        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-system-message",
                order: base + 150,
                canRender: { message in
                    message.role == .system
                },
                render: { message, showRawMessage in
                    SystemMessageView(message: message, showRawMessage: showRawMessage)
                }
            )
        )

        // 兜底 Markdown 渲染
        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-default-markdown",
                order: base - 10,
                canRender: { message in
                    !message.content.isEmpty
                },
                render: { message, showRawMessage in
                    DefaultMessageView(message: message, showRawMessage: showRawMessage)
                }
            )
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
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
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
    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility { WorkspaceVisibility() }
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
