import KernelLumi
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
    public var name: String {
        LumiPluginLocalization.string("Conversation Input", bundle: .module)
    }
    public let order = 83
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    // MARK: - 内部状态

    /// 输入状态（由内核注册并共享给输入视图和发送按钮）
    let inputState = InputState()

    // MARK: - Initialization

    public init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)ConversationInputPlugin")
        }
    }

    // MARK: - LumiPlugin

    public func onBoot(kernel: KernelLumi) async throws {
        try kernel.registerConversationInputService(inputState)
    }

    public func onReady(kernel: KernelLumi) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)register ➡️ kernel=\(String(describing: ObjectIdentifier(kernel)))")
            Self.logger.info("\(Self.t)boot 完成")
        }
    }

    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] {
        if Self.verbose {
            Self.logger.info("\(Self.t)chatSectionItems ➡️ 注册 1 个 .bottomFixed item (注入 kernel)")
        }
        let inputState = self.inputState
        return [
            ChatSectionItem(
                id: id,
                placement: .bottomFixed,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) {
                ConversationInputView(kernel: kernel, inputState: inputState)
            }
        ]
    }

    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] {
        let inputState = self.inputState
        return [
            ChatSectionActionBarItem(id: "\(id).send-button", placement: .trailing) {
                SendActionBarButton(kernel: kernel, inputState: inputState)
            }
        ]
    }


    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
