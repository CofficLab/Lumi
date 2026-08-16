import SwiftUI
import KernelLumi
import LumiUI

@MainActor
public final class QuickFileSearchPlugin: LumiPlugin {
    public let id = "QuickFileSearch"
    public var name: String {
        LumiPluginLocalization.string("Quick File Search", bundle: .module)
    }
    public let order = 50
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {
        // 注入文件选择回调：优先经 Editor 契约 V2 打开（单一事实源），
        // Host 未就绪的精简宿主回退 legacy EditorProviding。
        QuickFileSearchBridge.selectFileHandler = { [weak kernel] path, _ in
            Task { @MainActor in
                if let documents = kernel?.editorV2?.documents {
                    _ = try? await documents.open(EditorOpenRequest(uri: URL(fileURLWithPath: path)))
                } else {
                    try? await kernel?.editorProvider?.openFile(at: path)
                }
            }
        }

        // 注入窗口 ID 提供者（当前单窗口，返回 nil 即可）
        QuickFileSearchBridge.activeWindowIdProvider = { nil }

        // 启动快捷键监听
        FileSearchHotkeyManager.shared.startMonitoring()
    }

    // MARK: - Root Overlays

    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] {
        [
            LumiRootOverlayItem(id: id, order: order) { content in
                FileSearchOverlay(
                    content: content,
                    projectPathProvider: { [weak kernel] in
                        kernel?.project?.currentProject?.path ?? ""
                    },
                    windowIdProvider: { nil }
                )
            },
        ]
    }

    // MARK: - Settings

    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] {
        [
            SettingsTabItem(
                id: id,
                title: LumiPluginLocalization.string("Quick File Search", bundle: .module),
                systemImage: "magnifyingglass",
                order: order
            ) {
                QuickFileSearchSettingsView(
                    projectPath: kernel.project?.currentProject?.path ?? ""
                )
            },
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
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
