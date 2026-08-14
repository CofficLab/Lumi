import KernelLumi
import LumiUI
import SwiftUI

/// 产品原型设计助手插件。
///
/// 通过 `viewContainers(kernel:)` 贡献一个独立的视图容器，左侧为对话区、
/// 右侧为实时预览区。用户用自然语言描述界面需求，插件调用当前选中的 LLM
/// 流式生成单文件 HTML 原型，并在 `WKWebView` 中渲染；多轮对话即可持续精修。
///
/// 对话状态独立于主聊天（不写入 `MessageStore`），避免污染日常会话。
/// 默认关闭（`.optIn`），用户在插件管理中启用后生效。
@MainActor
public final class PrototypeDesignerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.prototype-designer"
    public var name: String { "Prototype Designer" }
    public var pluginDescription: String {
        "通过自然语言对话，借助 LLM 快速生成可交互的产品原型，并实时预览。"
    }

    /// 功能插件段（200-299），紧邻 WhiteNoise。
    public let order = 262
    public let policy: LumiPluginPolicy = .optIn
    public let category: LumiPluginCategory = .development
    public let stage: LumiPluginStage = .beta

    public init() {}

    // MARK: - Lifecycle

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {}

    // MARK: - View Container

    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "wand.and.stars",
                railVisibility: .unsupported,
                chatVisibility: .unsupported,
                panelHeaderVisibility: .unsupported,
                panelBottomVisibility: .unsupported
            ) {
                PrototypeDesignerView(kernel: kernel)
            }
        ]
    }

    // MARK: - Prompt Suggestions

    /// 贡献聊天起始提示词，点击时激活本容器（必要时先启用插件）。
    public func promptSuggestions(kernel: KernelLumi) -> [LumiPromptSuggestion] {
        [
            LumiPromptSuggestion(
                id: "\(id).start",
                title: "设计一个产品原型",
                systemImage: "wand.and.stars",
                action: .activateViewContainer(id)
            )
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
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
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
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
