import Foundation
import LumiKernel
import SwiftUI

/// StateMonitorPlugin — Lumi 的运行时状态联动层
///
/// 承载"监听一个权威状态源 → 维护/派生与之相关的内核状态"这类联动逻辑。
///
/// 当前职责:
/// - `OnConversationSelectedHook`:选中对话后,自动跟随其绑定的项目
///   (`kernel.conversations?.objectWillChange` → `kernel.project.openProject(at:)`)。
/// - `OnProjectChangedHook`:当前项目切换时,清空当前选中的对话
///   (`kernel.project.objectWillChange` → `kernel.conversations.deselectConversation()`)。
/// - `OnConversationProviderModelSyncHook`:选中对话后,把对话绑定的 Provider/Model
///   同步到内核全局(`kernel.conversations.objectWillChange` →
///   `kernel.llmProvider.selectProvider(id:)` / `selectModel(providerID:model:)`)。
///   仅在不一致时写入,无绑定则跳过,避免覆盖用户刚手动选择的全局值。
/// - `OnGlobalProviderModelSyncHook`:全局 Provider/Model 变化时,把全局选择同步到
///   当前对话(`.lumiSelectedRemoteProviderIDDidChange` /
///   `.lumiSelectedLocalProviderIDDidChange` / `.lumiSelectedModelsDidChange` →
///   `kernel.conversations.selectProvider(id:model:for:)`)。
///   仅在不一致时写入,避免覆盖用户刚手动选择的对话绑定。
/// - `OnConversationVerbositySyncHook`:选中对话后,把对话绑定的详细程度
///   同步到内核全局(`kernel.conversations.objectWillChange` →
///   `kernel.conversations.setGlobalVerbosity`)。
/// - `OnGlobalVerbositySyncHook`:全局详细程度变化时,把全局值同步到当前对话
///   (`kernel.conversations.objectWillChange` →
///   `kernel.conversations.setVerbosity(_:for:)`)。
///
/// 前两条 hook 形成对称联动:
///   - 选中对话 → 跟随对话绑定的项目;
///   - 项目变化 → 清空当前对话,避免旧对话与新项目不一致。
///
/// Provider/Model 两条 hook 形成对称联动:
///   - 选中对话 → 把对话的 Provider/Model 写入内核全局,使后续发送的消息使用对话绑定的模型;
///   - 全局 Provider/Model 变化 → 把全局选择同步到当前对话,使对话绑定与全局一致。
///
/// Verbosity 两条 hook 形成对称联动:
///   - 选中对话 → 把对话的详细程度写入内核全局;
///   - 全局详细程度变化 → 把全局值同步到当前对话,使对话绑定与全局一致。
///
/// 设计意图:
/// - 不产生新的状态源,只在已有状态之间建立联动规则;
/// - 所有 hook 都在 `onReady` 阶段 `attach`,确保依赖的服务已注册;
/// - `order = 75` 仅为占位避开其他核心插件。 Hook 真正依赖的 `conversations`
///   服务由 `ConversationManagerPlugin`(`order = 7`)在其 `onBoot` 注册,而
///   `onReady` 在所有插件的 `onBoot` 完成后才执行,因此 order 数值大小对依赖
///   关系不敏感。
@MainActor
public final class StateMonitorPlugin: LumiPlugin {

    // MARK: - LumiPlugin metadata

    public let id = "com.coffic.lumi.plugin.state-monitor"
    public let name = "State Monitor"
    public let order = 75
    public let policy: LumiPluginPolicy = .alwaysOn

    // MARK: - Hooks

    private let selectedProjectHook = OnConversationSelectedHook()
    private let projectChangedHook = OnProjectChangedHook()
    private let providerModelSyncHook = OnConversationProviderModelSyncHook()
    private let globalProviderModelSyncHook = OnGlobalProviderModelSyncHook()
    private let verbositySyncHook = OnConversationVerbositySyncHook()
    private let globalVerbositySyncHook = OnGlobalVerbositySyncHook()

    // MARK: - Init

    public init() {}

    // MARK: - LumiPlugin lifecycle

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        // 放在 onReady 而不是 onBoot:onBoot 只保证自己注册顺序里的服务可用,
        // onReady 才是「所有插件的 onBoot 已完成」之后,更稳。
        // 这里真正依赖的是 `kernel.conversations`(由更早 order 的
        // `ConversationManagerPlugin` 在我们之前注册),实际在 onBoot 阶段
        // 就已可用,但放 onReady 跟项目里其他 Hook 一致。
        selectedProjectHook.attach(kernel: kernel)
        projectChangedHook.attach(kernel: kernel)
        providerModelSyncHook.attach(kernel: kernel)
        globalProviderModelSyncHook.attach(kernel: kernel)
        verbositySyncHook.attach(kernel: kernel)
        globalVerbositySyncHook.attach(kernel: kernel)
    }

    public func onDisable(kernel: LumiKernel) async throws {
        selectedProjectHook.detach()
        projectChangedHook.detach()
        providerModelSyncHook.detach()
        globalProviderModelSyncHook.detach()
        verbositySyncHook.detach()
        globalVerbositySyncHook.detach()
    }

    // MARK: - Empty contribution points
    // StateMonitorPlugin 不贡献 UI / LLM Provider / Agent Tool,
    // 它的存在意义是承载运行时的联动逻辑。所有贡献点返回空。

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
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
