import Foundation
import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// CAD Designer 插件
///
/// 提供铝型材 CAD 设计功能的插件,支持项目创建、组件放置、连接生成等操作。
@MainActor
public final class CADDesignerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.cad-designer")
    public nonisolated static let emoji = "📐"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.cad-designer"
    public var name: String { CADDesignerLocalization.string("CAD Designer") }
    public var pluginDescription: String { CADDesignerLocalization.string("Design aluminum profile frames with 3D preview, BOM, and cut optimization.") }
    public let order = 80
    public let policy: LumiPluginPolicy = .optIn
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        try await CADDesignerOnBootHook().execute(kernel)
    }

    public func onReady(kernel: LumiKernel) async throws {
        try await CADDesignerOnReadyHook().execute(kernel)
    }

    // MARK: - Agent Tools

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        [
            CreateCADProjectTool(),
            LoadCADProjectTool(),
            SaveCADProjectTool(),
            BuildFrameTool(),
            PlaceProfileTool(),
            PlaceConnectorTool(),
            ConnectComponentsTool(),
            UpdateProfileTool(),
            GenerateBOMTool(),
            OptimizeCuttingTool(),
        ]
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
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(CADDesignerAboutView())
    }
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
