import AppKit
import AppUpdatePlugin
import FactoryLumi
import Foundation
import KernelCore
import LumiFactory
import SwiftUI

/// Lumi 的宿主清单：装配流水线由共享引擎 `LumiFactory` 解释，本文件只声明 Lumi
/// 与兄弟 App 的差异（品牌、插件目录、存储/主题、根视图与状态栏）。
///
/// 原来的 `LumiApp` / `LumiAppDelegate` / `LumiMenuBarController` 各自实现了同一
/// 套流程，其中状态栏弹窗未跟进 `MenuBarHostKit` 的尺寸契约（`popoverSizing`
/// 由 `.intrinsic` 改为宿主显式设置 `contentSize`），弹窗内容因此被裁切。
@MainActor
enum LumiAssembly {
    private static let pluginManagerID = "com.coffic.lumi.plugin.plugin-manager"
    private static let toolManagerID = "com.coffic.lumi.plugin.tool-manager"

    static func makeManifest() -> HostManifest {
        // 同一个实例负责「产出插件」与「Provider 就位后回填」：聊天区可见性代理
        // 挂在实例上，两处必须看到同一个代理，否则 Booklet Maker 的显隐失效。
        let pluginFactory = DefaultPluginFactory()
        let providerFactory = DefaultProviderFactory(
            dataRootDirectory: KernelFactory.uiTestingDataRootDirectory()
        )

        return HostManifest(
            identity: HostIdentity(
                appName: "Lumi",
                loggerSubsystem: "com.coffic.lumi",
                mainWindowID: "lumi.main",
                settingsWindowID: "lumi.settings",
                accessibilityPrefix: "lumi",
                mainWindowDefaultSize: CGSize(width: 1100, height: 760),
                settingsWindowDefaultSize: CGSize(width: 800, height: 500)
            ),
            makePlugins: {
                pluginFactory.makePlugins()
            },
            storage: HostStorageConfiguration(
                stateStorePluginID: pluginManagerID,
                dataRootDirectoryOverride: { KernelFactory.uiTestingDataRootDirectory() },
                legacyDirectoryMigrations: [
                    pluginManagerID: ["PluginManager"],
                    toolManagerID: ["ToolManager"],
                ]
            ),
            // 新插件 id 读不到数据时回退旧目录/旧 id，升级不丢用户的启用状态。
            legacyPluginIDAliases: DefaultProviderFactory.pluginIDAliases,
            // Lumi 的根视图是工作台三栏（Rail + 内容 + 聊天分栏），
            // 共享的 `FactoryRootViewProviding`（工具栏 + 入口栏 + 内容）承载不了。
            makeRootViewProvider: {
                providerFactory.makeRootViewProvider()
            },
            registerProviders: { kernel in
                // 与基线同名的区域 Provider 走「已存在则跳过」，避免
                // providerAlreadyRegistered；App 域 Provider 照常注册。
                try providerFactory.registerProviders(into: kernel)
                pluginFactory.didRegisterProviders(in: kernel)
            },
            wireKernel: { kernel in
                // 更新服务要在设置视图物化前就位，通用页才渲染得出通道选择器。
                AppUpdateBootstrap.start(kernel: kernel)
                // 根视图的区域写入（工具栏 / 入口栏 / Rail / 内容 / 聊天分栏）。
                // 关闭共享接线：Workbench 根视图的注入守卫只比较「有无值」，
                // 共享接线先注入默认内容会把插件后续的内容替换挡死。
                LumiRegionWiring.wire(kernel: kernel)
            },
            makeMainView: { kernel in
                DefaultViewFactory.shellMainView(kernel: kernel)
            },
            features: HostFeatures(
                statusBar: HostStatusBarConfiguration(
                    statusViewHeight: 20,
                    popoverWidth: 280,
                    popoverMaximumHeight: 800,
                    // 已发布的 UI 测试锚点，不随前缀约定改名。
                    accessibilityIdentifier: "lumi.menu-bar",
                    makeIconView: { kernel in AnyView(LumiStatusBarView(kernel: kernel)) },
                    menuItems: statusMenuItems()
                ),
                // 设置齿轮由 SettingsToolbarPlugin 贡献，不能再挂一个。
                showsSettingsToolbarButton: false,
                openExternalPath: { kernel, url in
                    LumiExternalPaths.open(url, kernel: kernel)
                },
                checkForUpdates: { UpdateService.shared.checkForUpdates() },
                // UI 测试依赖大量后代标识（会话、消息、工具卡片…），
                // 容器级 id 会被 SwiftUI 传播给后代并遮蔽它们。
                appliesWindowContentIdentifiers: false,
                usesReadyMarkerOverlays: true,
                skipsSharedRootViewWiring: true
            )
        )
    }

    private static func statusMenuItems() -> [HostStatusMenuItem] {
        [
            HostStatusMenuItem(
                title: NSLocalizedString("Open Lumi", comment: ""),
                windowID: "lumi.main",
                accessibilityIdentifier: "lumi.statusbar.main",
                action: { NSApp.activate(ignoringOtherApps: true) }
            ),
            HostStatusMenuItem(
                title: NSLocalizedString("Check for Updates", comment: ""),
                accessibilityIdentifier: "lumi.statusbar.updates",
                action: { UpdateService.shared.checkForUpdates() }
            ),
            HostStatusMenuItem(
                title: NSLocalizedString("Quit Lumi", comment: ""),
                accessibilityIdentifier: "lumi.statusbar.quit",
                isDestructive: true,
                action: { NSApp.terminate(nil) }
            ),
        ]
    }
}

/// Finder 右键扩展的 `lumi://finder/*` 深链与外部文件 / 目录的派发。
///
/// 深链不能交给内核：它要改的是 Finder 自己的偏好，与 Lumi 的数据无关；
/// 其余路径交给 `KernelFactory`，目录切换当前项目、文件交给已注册的处理插件。
@MainActor
enum LumiExternalPaths {
    static func open(_ url: URL, kernel: KernelCoreContainer) {
        if handleFinderCommand(url, kernel: kernel) { return }
        guard url.isFileURL else { return }
        let path = url.standardizedFileURL.path
        Task { await KernelFactory.openExternalPath(path, kernel: kernel) }
    }

    private static func handleFinderCommand(_ url: URL, kernel: KernelCoreContainer) -> Bool {
        guard url.scheme == urlScheme, url.host == "finder" else { return false }
        switch url.path {
        case "/show-hidden": return handleShowHiddenCommand(url)
        case "/open-project": return handleOpenProjectCommand(url, kernel: kernel)
        default: return false
        }
    }

    /// 处理 `lumi://finder/show-hidden?value=true|false`。
    private static func handleShowHiddenCommand(_ url: URL) -> Bool {
        guard let value = queryValue(for: "value", in: url),
              let showHiddenFiles = Bool(value) else {
            return false
        }

        let defaults = Process()
        defaults.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        defaults.arguments = [
            "write", "com.apple.finder", "AppleShowAllFiles", "-bool",
            showHiddenFiles ? "true" : "false",
        ]
        try? defaults.run()
        defaults.waitUntilExit()
        guard defaults.terminationStatus == 0 else { return true }

        let restart = Process()
        restart.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        restart.arguments = ["Finder"]
        try? restart.run()
        return true
    }

    /// 处理 `lumi://finder/open-project?path=<文件夹绝对路径>`。
    private static func handleOpenProjectCommand(_ url: URL, kernel: KernelCoreContainer) -> Bool {
        guard let path = queryValue(for: "path", in: url),
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        // 目录走与外部拖入相同的路径语义：切换当前项目。
        let standardized = (path as NSString).standardizingPath
        Task { @MainActor in
            _ = await KernelFactory.openExternalPath(standardized, kernel: kernel)
        }
        return true
    }

    private static func queryValue(for name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }

    private static var urlScheme: String {
        (Bundle.main.object(forInfoDictionaryKey: "LumiURLScheme") as? String) ?? "lumi"
    }
}
