import KernelLumi
import LumiUI
import SwiftUI

/// 产品原型设计助手插件。
///
/// 采用 AppIconDesigner 同款模式：贡献 `agentTools` 复用主聊天区域，不自建独立面板。
/// - `generate_prototype` / `refine_prototype` 两个工具内部调用当前选中的 LLM，
///   生成/修改单文件 HTML 原型；
/// - `willSendToLLM` 注入工具说明书，教主 Agent 在用户想做原型设计时调用这些工具；
/// - `messageRenderers` 贡献一个渲染器，把含 `<artifact>` 的工具结果渲染成内嵌的
///   WKWebView 交互预览。
///
/// 默认关闭（`.optIn`），用户在插件管理中启用后生效。
@MainActor
public final class PrototypeDesignerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.prototype-designer"
    public var name: String { "Prototype Designer" }
    public var pluginDescription: String {
        "通过自然语言对话，借助 LLM 快速生成可交互的产品原型，并在聊天中实时预览。"
    }

    /// 功能插件段（200-299），紧邻 WhiteNoise。
    public let order = 262
    public let policy: LumiPluginPolicy = .optIn
    public let category: LumiPluginCategory = .agent
    public let stage: LumiPluginStage = .beta

    public init() {}

    // MARK: - Lifecycle

    public func onBoot(kernel: KernelLumi) async throws {
        PrototypeDesignerRuntime.shared.reset()
    }

    public func onReady(kernel: KernelLumi) async throws {}

    // MARK: - Agent Tools（复用主聊天，参考 AppIconDesigner 模式）

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [GeneratePrototypeTool(), RefinePrototypeTool()]
    }

    /// 注入工具使用说明，引导主 Agent 在合适时机调用原型设计工具。
    public func willSendToLLM(kernel: KernelLumi, messages: [LumiChatMessage]) async -> [LumiChatMessage] {
        guard let conversationID = messages.last?.conversationID else { return messages }
        let guidance = LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: PrototypePromptBuilder.agentGuidance
        )
        return [guidance] + messages
    }

    // MARK: - 消息渲染器（把原型工具结果渲染成交互预览）

    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] {
        [PrototypeArtifactRenderer.item]
    }

    // MARK: - Prompt Suggestions

    public func promptSuggestions(kernel: KernelLumi) -> [LumiPromptSuggestion] {
        [
            LumiPromptSuggestion(
                id: "\(id).login",
                title: "设计一个登录页",
                prompt: "帮我设计一个手机 App 的登录页面，包含邮箱/密码登录、记住我，以及第三方登录入口。",
                systemImage: "person.crop.circle.badge.checkmark"
            ),
            LumiPromptSuggestion(
                id: "\(id).dashboard",
                title: "设计数据看板",
                prompt: "帮我设计一个桌面端的数据看板首页，包含关键指标卡片、趋势图区域和最近订单列表。",
                systemImage: "chart.bar.fill"
            ),
            LumiPromptSuggestion(
                id: "\(id).shop",
                title: "设计电商商品列表",
                prompt: "帮我设计一个电商 App 的商品列表页，带顶部搜索、分类入口和商品卡片。",
                systemImage: "cart.fill"
            ),
        ]
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
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
