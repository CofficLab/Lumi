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

    public let id = "com.coffic.lumi.plugin.app-manager"
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

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        // 设置插件数据目录
        if let storage = kernel.storage {
            Self.pluginDataDirectoryProvider = { storage.pluginDataDirectory(for: "AppManagerPlugin") }
        }
    }

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
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

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: "app-manager.sidebar",
                title: PluginAppManagerLocalization.string("Apps"),
                systemImage: "apps.iphone",
                visibility: .viewContainer(id: id)
            ) {
                AppRailView(viewModel: self.sharedViewModel)
            },
        ]
    }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(AppManagerAboutView())
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
