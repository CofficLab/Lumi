import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// Message List Plugin
///
/// Provides the chat message list view in the ChatSection.
@MainActor
public final class MessageListPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-list")
    nonisolated public static let emoji = "💬"
    nonisolated public static let verbose = false

    /// Live-resize 期间是否用轻量占位行（骨架视图）替换富文本子树。
    ///
    /// `true`:resize 时把 `MessageRowView` 换成 `MessageResizePlaceholder`,
    ///        牺牲 resize 期间的视觉真实性,换取每帧富文本 layout 的 0 遍历,
    ///        适合超长会话/老硬件。
    /// `false`(默认):resize 期间始终渲染富文本子树,避免出现骨架视图带来的
    ///        视觉跳动/与真实内容不一致的体验。
    ///
    /// 关闭后 `LiveResizeDetector` 仍会被挂载(零尺寸、不参与命中测试,
    /// 代价可忽略),但 `isLiveResizing` 分支不再触发,`ForEach` 永远走
    /// `MessageRowView` 分支。
    nonisolated public static let enableLiveResizeSkeleton: Bool = false

    public let id = "com.coffic.lumi.plugin.message-list"
    public var name: String {
        LumiPluginLocalization.string("Message List", bundle: .module)
    }
    public let order = 82
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {}


    // MARK: - Chat Section Items

    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] {
        [
            ChatSectionItem(
                id: id,
                placement: .stack,
                fillsRemainingHeight: true
            ) {
                ListView(kernel: kernel)
            }
        ]
    }


    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
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
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
