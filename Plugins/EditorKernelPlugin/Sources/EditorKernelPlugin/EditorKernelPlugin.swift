import Foundation
import LumiKernel
import os
import SuperLogKit
import SwiftUI

/// 编辑器内核插件
///
/// 负责 EditorService 实例的装配与生命周期管理。
/// 在 OnBoot 阶段创建 `EditorExtensionRegistry` + `EditorService`,
/// 并以**具象类型** `EditorService.self` 注册到内核(区别于 `EditorProviding.self`,
/// 后者由 `EditorProviderPlugin` 提供文件/主题能力契约)。
///
/// 注册顺序约束:`EditorKernelPlugin` 必须在 `EditorProviderPlugin` 的 OnReady 之前完成
/// OnBoot,以便后者把文件操作转发到真正的 `EditorService`。
@MainActor
public final class EditorKernelPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-kernel")
    public nonisolated static let emoji = "🧩"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.editor-kernel"
    public var name: String {
        LumiPluginLocalization.string("Editor Kernel Plugin", bundle: .module)
    }
    public let order = 1
    public let policy: LumiPluginPolicy = .alwaysOn // 核心插件

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onBoot(kernel: LumiKernel) async throws {
        try await EditorKernelOnBootHook().execute(kernel)
    }

    public func onReady(kernel: LumiKernel) async throws {
        try EditorKernelOnReadyHook().execute(kernel)
    }

    // MARK: - LumiPlugin stubs

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
