import LocalizationKit
import KernelLumi
import SwiftUI

/// Plugin Manager Plugin
///
/// 通过 `settingsTabItems(kernel:)` 贡献一个"插件管理"设置标签页,
/// 枚举并管理所有已注册插件(列表 / 搜索 / 分类筛选 / 阶段徽标 / 启用开关 / 详情),
/// 对齐旧版本 4.19.0 的体验。本插件自身 `.alwaysOn`,不可被禁用。
///
/// - 位置:`order = 90`,在内核启动早期完成 UI 贡献注册
/// - 策略:`.alwaysOn`
@MainActor
public final class PluginManagerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.plugin-manager"
    public var name: String {
        LumiPluginLocalization.string("Plugin Manager", bundle: .module)
    }
    public let order = 90
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    private var enabledStateStore: PluginEnabledStateStore?
    private var pluginController: PluginController?

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        guard let storage = kernel.storage else { return }
        let directory = storage.pluginDataDirectory(for: "PluginManager")
        let store = PluginEnabledStateStore(pluginDirectory: directory)
        enabledStateStore = store
        // PluginManagerPlugin owns persistence. The kernel manager only receives
        // the already loaded runtime state and never touches the storage layer.
        kernel.pluginManager.applyPersistedPluginStates(store.loadPluginEnabledOverrides())

        // 注册插件控制能力（运行时启停 + 持久化 + 同步重建），供空态提示词等 UI
        // 通过 kernel.pluginControl 调用。
        let controller = PluginController(kernel: kernel, store: store)
        pluginController = controller
        try kernel.registerPluginControlling(controller)
    }

    /// 更新插件启用状态：委托给 `PluginController`（运行时 + 持久化 + 同步重建）。
    public func setPluginEnabled(kernel: KernelLumi, id: String, enabled: Bool) async {
        await pluginController?.setEnabled(id: id, enabled: enabled)
    }

    /// 清除用户覆盖，回落到插件声明的默认策略。
    public func resetPluginEnabledState(kernel: KernelLumi, id: String) async {
        guard let store = enabledStateStore else { return }
        guard await kernel.pluginManager.resetPluginEnabledState(id: id) else { return }
        store.clearPluginEnabledOverride(for: id)
    }

    public func onReady(kernel: KernelLumi) async throws {}

    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] {
        [
            SettingsTabItem(
                id: id,
                title: PluginManagerText.string(PluginManagerText.plugins),
                systemImage: "puzzlepiece.extension",
                order: 3
            ) {
                PluginManagementView(kernel: kernel)
            },
        ]
    }

    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 6) {
                Text(PluginManagerText.string(PluginManagerText.plugins))
                    .font(.headline)
                Text(PluginManagerText.string(PluginManagerText.aboutDescription))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        )
    }

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
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
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
