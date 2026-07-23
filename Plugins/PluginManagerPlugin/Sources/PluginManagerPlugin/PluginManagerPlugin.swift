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
    public let name = "Plugin Manager"
    public let order = 90
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {}

    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
        [
            SettingsTabItem(
                id: id,
                title: PluginManagerText.string(PluginManagerText.plugins),
                systemImage: "puzzlepiece.extension"
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
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
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
    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility { WorkspaceVisibility() }
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
