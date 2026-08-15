import Foundation
import KernelLumi
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

    public let id = "com.coffic.lumi.plugin.app-manager"

    /// 本插件 rail 面板的稳定标识（注册为 `PanelRailTabItem.id`）。
    public nonisolated static let railTabID = "app-manager.sidebar"

    public var name: String {
        PluginAppManagerLocalization.string("App Manager")
    }
    public let order = 242
    public let policy: LumiPluginPolicy = .optIn
    public let stage: LumiPluginStage = .beta

    /// 插件级唯一的 AppManagerViewModel 实例。
    /// 通过 `viewContainers` 和 `panelRailTabItems` 同时注入，
    /// 让 AppRailView（侧边栏）与 AppManagerView（内容区）共享同一份
    /// 应用列表 / 选中状态，避免"在侧边栏选了应用但详情没同步"的问题。
    private let sharedViewModel = AppManagerViewModel()

    /// 插件数据目录解析器（由 storage.pluginDataDirectory(for:) 提供）
    nonisolated(unsafe) public static var pluginDataDirectoryProvider: () -> URL = {
        AppManagerPluginRuntimeBridge.fallbackPluginDataDirectory
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {
        // 设置插件数据目录
        if let storage = kernel.storage {
            Self.pluginDataDirectoryProvider = { storage.pluginDataDirectory(for: "AppManagerPlugin") }
        }
    }

    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: PluginAppManagerLocalization.string("App Manager"),
                systemImage: "apps.ipad",
                railVisibility: .alwaysVisible,
                chatVisibility: .unsupported,
                panelHeaderVisibility: .unsupported,
                panelBottomVisibility: .unsupported
            ) {
                AppManagerView(viewModel: self.sharedViewModel)
            },
        ]
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(id).title",
                title: name,
                placement: .center,
                order: 0
            ) {
                AppManagerToolbarTitleView(containerID: self.id, kernel: kernel, title: self.name)
            },
        ]
    }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: Self.railTabID,
                title: PluginAppManagerLocalization.string("Apps"),
                systemImage: "apps.iphone",
                visibility: .viewContainer(id: id)
            ) {
                AppRailView(viewModel: self.sharedViewModel)
            },
        ]
    }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(AppManagerAboutView())
    }
    public func pluginManualView(kernel: KernelLumi) -> AnyView? {
        AnyView(AppManagerManualView())
    }
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

// MARK: - Runtime Bridge

enum AppManagerPluginRuntimeBridge {
    /// StoragePlugin 未就绪时的兜底数据目录。
    /// 刻意复刻项目级约定路径（与 `StoragePlugin.makeDefaultDataRootDirectory`
    /// 及 `StorageService.pluginDataDirectory(for:)` 保持一致）：
    /// `<Application Support>/<bundleID>/db_<debug|production>_v<major>/AppManagerPlugin/`
    /// 避免与注入后的标准路径分叉，导致同一份缓存数据落到两处目录。
    static let fallbackPluginDataDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4"
        let majorVersion = version.split(separator: ".").first.flatMap { Int($0) } ?? 4

        #if DEBUG
        let dbDirectoryName = "db_debug_v\(majorVersion)"
        #else
        let dbDirectoryName = "db_production_v\(majorVersion)"
        #endif

        return appSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent(dbDirectoryName, isDirectory: true)
            .appendingPathComponent("AppManagerPlugin", isDirectory: true)
    }()
}
