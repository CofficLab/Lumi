import Foundation
import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// App Manager Plugin
///
/// Browse installed macOS applications.
@MainActor
public final class AppManagerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-manager")
    nonisolated public static let emoji = "📱"
    nonisolated public static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.app-manager"
    public let name = "App Manager"
    public let order = 42
	public let policy: LumiPluginPolicy = .disabled

    /// 数据根目录解析器
    nonisolated(unsafe) public static var databaseRootURLProvider: () -> URL = {
        AppManagerPluginRuntimeBridge.fallbackRootDirectory
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        // 设置数据目录
        if let storage = kernel.storage {
            AppManagerPluginRuntimeBridge.dataRootDirectory = storage.dataRootDirectory
            Self.databaseRootURLProvider = { storage.dataRootDirectory }
        }

        guard policy.shouldRegister else { return }
        kernel.viewContainer?.register(
            ViewContainerItem(
                id: id,
                title: "App Manager",
                systemImage: "apps.ipad"
            ) {
                AppManagerView()
            }
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 App Manager 视图容器到内核")
            Self.logger.info("\(Self.t)App Manager 插件启动完成")
        }
    }


    // MARK: - LumiPlugin stubs

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
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
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

// MARK: - Runtime Bridge

enum AppManagerPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?

    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()
}