import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// Conversation Input Plugin
///
/// 向 Chat 区域添加输入框和发送按钮。
@MainActor
public final class ConversationInputPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-input")
    public nonisolated static let emoji = "⌨️"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.conversation-input"
    public let name = "Conversation Input"
    public let order = 83
    public let policy: LumiPluginPolicy = .optOut

    // MARK: - 内部状态

    /// 输入状态（供输入视图和发送按钮共享）
    let inputState = InputState()

    // MARK: - Initialization

    public init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)ConversationInputPlugin")
        }
    }

    // MARK: - LumiPlugin

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)register ➡️ kernel=\(String(describing: ObjectIdentifier(kernel)))")
            Self.logger.info("\(Self.t)boot 完成")
        }
    }

    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] {
        if Self.verbose {
            Self.logger.info("\(Self.t)chatSectionItems ➡️ 注册 1 个 .bottomFixed item (注入 kernel)")
        }
        return [
            ChatSectionItem(
                id: id,
                placement: .bottomFixed,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) {
                ConversationInputView(kernel: kernel, inputState: self.inputState)
            }
        ]
    }

    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] {
        [
            ChatSectionActionBarItem(
                id: "\(id).send-button"
            ) {
                SendButtonView(kernel: kernel, inputState: self.inputState)
            }
        ]
    }


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
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
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
