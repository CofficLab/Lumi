import FactoryCore
import FactoryLumi
import SwiftUI

@main
struct AppIconDesignerApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: MacAgent

    private static let appIconDesignerPluginID = "com.coffic.lumi.plugin.app-icon-designer"

    /// 过渡期：仍通过 FactoryLumi 的 ID 选择 API 从完整目录筛选插件。
    /// 待建立专属 FactoryAppIconDesigner 后，应改为编译期最小组合，
    /// 不再链接完整插件图。当前行为与重构前的白名单完全一致。
    private static let hostConfiguration = try? FactoryLumi.configuration(
        allowingIDs: [
            "com.coffic.lumi.plugin.storage",
            "com.coffic.lumi.plugin.projects",
            "com.coffic.lumi.plugin.layout",
            "com.coffic.lumi.plugin.command",
            "com.coffic.lumi.plugin.message-sender",
            "com.coffic.lumi.plugin.llm-provider-manager",
            "com.coffic.lumi.plugin.agent-turn-runner",
            "com.coffic.lumi.plugin.editor-kernel",
            "com.coffic.lumi.plugin.editor-provider",
            "com.coffic.lumi.plugin.tool-manager",
            "com.coffic.lumi.plugin.settings",
            "com.coffic.lumi.plugin.logo",
            "com.coffic.lumi.plugin.theme-manager",
            "com.coffic.lumi.plugin.theme.lumi",
            "CoreMessageRenderer",
            appIconDesignerPluginID,
        ],
        enabledPluginIDs: [appIconDesignerPluginID],
        initialContainerID: appIconDesignerPluginID,
        showsStatusBar: false,
        showsActivityBar: false
    )

    var body: some Scene {
        WindowGroup("AppIconDesigner", id: "app-icon-designer.main") {
            FactoryCore.makeMainWindow(configuration: Self.hostConfiguration!)
                .environmentObject(appDelegate)
                .onReceive(appDelegate.$pendingOpenPath.compactMap { $0 }) { path in
                    OpenProjectHandler.shared.requestOpen(path: path)
                    appDelegate.pendingOpenPath = nil

                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.windows.first(where: \.canBecomeKey)?.makeKeyAndOrderFront(nil)
                    }
                }
        }
        .handlesExternalEvents(matching: Set())
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 900)
        .commands {
            FactoryCore.makeCommands()
        }

        // ActivityBar 目前使用这个稳定 ID 打开设置窗口；独立进程中可安全复用。
        Window("设置", id: AppBootstrap.settingsWindowID) {
            FactoryCore.makeSettingsWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 780, height: 600)
    }
}
