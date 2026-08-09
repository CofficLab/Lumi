import LocalizationKit
import LumiKernel
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

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        guard let storage = kernel.storage else { return }
        let directory = storage.pluginDataDirectory(for: "PluginManager")
        let store = PluginEnabledStateStore(pluginDirectory: directory)
        enabledStateStore = store
        // PluginManagerPlugin owns persistence. The kernel manager only receives
        // the already loaded runtime state and never touches the storage layer.
        kernel.pluginManager.applyPersistedPluginStates(store.loadPluginEnabledOverrides())
    }

    /// 更新插件启用状态：先持久化用户意图，再通知内核应用运行时状态。
    public func setPluginEnabled(kernel: LumiKernel, id: String, enabled: Bool) async {
        guard let store = enabledStateStore else { return }
        guard kernel.pluginManager.plugin(id: id)?.policy.isConfigurable == true else { return }
        guard kernel.pluginManager.isPluginEnabled(id: id) != enabled else { return }

        guard await kernel.pluginManager.setPluginEnabled(id: id, enabled: enabled) else { return }
        store.savePluginEnabledOverride(enabled, for: id)
    }

    /// 清除用户覆盖，回落到插件声明的默认策略。
    public func resetPluginEnabledState(kernel: LumiKernel, id: String) async {
        guard let store = enabledStateStore else { return }
        guard await kernel.pluginManager.resetPluginEnabledState(id: id) else { return }
        store.clearPluginEnabledOverride(for: id)
    }

    public func onReady(kernel: LumiKernel) async throws {}

    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
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

    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
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
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
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
