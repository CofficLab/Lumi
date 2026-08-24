import KernelLumi
import LocalizationKit
import LumiUI
import os
import SwiftUI
import SuperLogKit

/// 代码编辑器插件
///
/// 在 ActivityBar 中贡献 "Code Editor" 视图容器，显示当前文件的内容。
/// 当前文件来自 `kernel.project?.currentFileURL`（由 `ProjectProviding` 提供）。
@MainActor
public final class EditorPanelPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.lumi-editor")
    public nonisolated static let emoji = "📝"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "LumiEditor"
    public var name: String {
        LumiPluginLocalization.string("Code Editor", bundle: .module)
    }
    public let order = 277
    public let policy: LumiPluginPolicy = .optIn
    public let category: LumiPluginCategory = .development
    public let stage: LumiPluginStage = .beta
    public var pluginDescription: String {
        LumiPluginLocalization.string("Display the content of the current project file.", bundle: .module)
    }

    public init() {}

    // MARK: - LumiPlugin Contributions

    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "chevron.left.forwardslash.chevron.right",
                supportsProject: true,
                railVisibility: .visibleByDefault,
                chatVisibility: .visibleByDefault,
                panelHeaderVisibility: .visibleByDefault,
                panelBottomVisibility: .visibleByDefault
            ) {
                EditorPanelHostView(kernel: kernel)
            }
        ]
    }

    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(EditorPanelAboutView())
    }

    public func pluginManualView(kernel: KernelLumi) -> AnyView? {
        AnyView(EditorPanelManualView())
    }

    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }

    // MARK: - LumiPlugin stubs

    public func onBoot(kernel: KernelLumi) async throws {}
    public func onReady(kernel: KernelLumi) async throws {}
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
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
