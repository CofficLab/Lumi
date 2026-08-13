import Foundation
import KernelLumi
import LumiUI
import SwiftUI

/// Debug Badge Plugin
///
/// 在 Debug 构建下，于标题工具栏左上角显示一个橙色「DEBUG」胶囊徽标，
/// 提示用户当前运行的是 Debug 构建（行为类似 Flutter 的 debug 标识）。
///
/// 徽标视图本身由 `#if DEBUG` 编译剔除，Release 构建中插件不贡献任何工具栏项；
/// 同时 `policy` 在 Release 下为 `.disabled`，确保零足迹。
@MainActor
public final class DebugBadgePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.debug-badge"
    public var name: String {
        LumiPluginLocalization.string("Debug Badge", bundle: .module)
    }
    public let order = 900
    #if DEBUG
    public let policy: LumiPluginPolicy = .alwaysOn
    #else
    public let policy: LumiPluginPolicy = .disabled
    #endif
    public let stage: LumiPluginStage = .beta
    public var category: LumiPluginCategory = .development

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {}

    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] {
        #if DEBUG
        return [
            LumiTitleToolbarItem(
                id: "\(id).badge",
                title: LumiPluginLocalization.string("Running a Debug build", bundle: .module),
                placement: .leading,
                order: 900
            ) {
                DebugBadgeView()
            },
        ]
        #else
        return []
        #endif
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
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

/// 标题工具栏左上角的「DEBUG」胶囊徽标。
///
/// 使用主题 `warning` 色（橙 #FF9F0A）作为背景，白色粗体文字，
/// 与 Lumi 主题体系保持一致。
#if DEBUG
private struct DebugBadgeView: View {
    @LumiTheme private var theme: any LumiUITheme

    var body: some View {
        Text("DEBUG")
            .font(.appMicroEmphasized)
            .tracking(0.3)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(theme.warning, in: Capsule())
    }
}
#endif
