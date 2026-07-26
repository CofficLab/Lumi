import EditorService
import LumiKernel
import LumiUI
import os
import SwiftUI
import SuperLogKit

/// 代码编辑器插件
///
/// 在 ActivityBar 中贡献 "Code Editor" 视图容器,托管 EditorService 驱动的编辑器面板。
/// policy 为 .alwaysOn(用户不可禁用);容器激活时由 BuiltinPluginManager 应用可见性
/// (隐藏聊天区、显示 rail 与 panel)。
@MainActor
public final class EditorPanelPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.lumi-editor")
    public nonisolated static let emoji = "📝"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "LumiEditor"
    public let name = LumiPluginLocalization.string("Code Editor", bundle: .module)
    public let order = 277
    public let policy: LumiPluginPolicy = .alwaysOn
    public let category: LumiPluginCategory = .development
    public let stage: LumiPluginStage = .beta
    public var pluginDescription: String {
        LumiPluginLocalization.string("Code editor with file tree, LSP, and workspace panels.", bundle: .module)
    }

    public init() {}

    // MARK: - LumiPlugin Contributions

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "chevron.left.forwardslash.chevron.right",
                isRailVisible: true,
                isChatVisible: true,
                isContentVisible: true,
                isPanelVisible: true,
                isPanelHeaderVisible: true,
                isPanelBottomVisible: true
            ) {
                EditorPanelHostView(kernel: kernel)
            }
        ]
    }

    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text(name)
                    .font(.title2.weight(.semibold))
                Text(pluginDescription)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }

    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }

    // MARK: - LumiPlugin stubs

    public func onBoot(kernel: LumiKernel) async throws {}
    public func onReady(kernel: LumiKernel) async throws {}
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
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
