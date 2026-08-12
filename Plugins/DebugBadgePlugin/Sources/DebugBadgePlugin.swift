import Foundation
import LumiKernel
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
    // Debug 构建默认开启（徽标自动显示，可手动关闭）；
    // Release 构建硬禁用（且徽标本就已被 #if DEBUG 编译剔除）。
    #if DEBUG
    public let policy: LumiPluginPolicy = .optOut
    #else
    public let policy: LumiPluginPolicy = .disabled
    #endif
    public let stage: LumiPluginStage = .beta
    public var category: LumiPluginCategory = .development

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {}

    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] {
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

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
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
