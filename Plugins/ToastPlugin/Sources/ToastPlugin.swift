import KernelLumi
import SuperLogKit
import SwiftUI
import os

/// Toast 插件:实现内核 `ToastProviding` 能力。
///
/// 在 `onBoot` 中注册 `ToastCenter`(状态机:替换式节流 + 自动消失),
/// 并以根覆盖层方式在主窗口顶部渲染。任何持有内核的代码可通过
/// `kernel.toast?.show(...)` 发出提示。
@MainActor
public final class ToastPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "🍞"
    public nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.toast", category: "ToastPlugin")

    public let id = "com.coffic.lumi.plugin.toast"
    public var name: String {
        LumiPluginLocalization.string("Toast", bundle: .module)
    }
    public let order = 95
    public let policy: LumiPluginPolicy = .alwaysOn
    public let category: LumiPluginCategory = .general
    public let stage: LumiPluginStage = .beta
    public var pluginDescription: String {
        LumiPluginLocalization.string("在应用窗口顶部展示瞬时 Toast 提示，供内核与其他插件调用。", bundle: .module)
    }

    /// Toast 状态机,由根覆盖层订阅渲染。
    private let center = ToastCenter()

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        try kernel.registerToastService(center)
    }

    public func onReady(kernel: KernelLumi) async throws {}

    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] {
        [
            LumiRootOverlayItem(id: "\(id).overlay", order: order, wrap: { content in
                AnyView(ToastOverlay(content: content, center: self.center))
            })
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
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
