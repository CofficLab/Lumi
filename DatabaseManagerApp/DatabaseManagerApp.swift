import LumiFactory
import SwiftUI

@main
struct DatabaseManagerApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: MacAgent

    private static let databaseManagerPluginID = "com.coffic.lumi.plugin.database-manager"

    /// 独立应用的插件集合是有意维护的严格白名单。
    /// LumiFactory 不会根据依赖关系自动扩充它。
    private static let hostConfiguration = LumiHostConfiguration(
        pluginAllowlist: [
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
            databaseManagerPluginID,
        ],
        enabledPluginIDs: [databaseManagerPluginID],
        initialContainerID: "database-manager",
        showsStatusBar: false,
        showsActivityBar: false
    )

    var body: some Scene {
        WindowGroup("DatabaseManager", id: "database-manager.main") {
            LumiFactory.makeMainWindow(configuration: Self.hostConfiguration)
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
        .defaultSize(width: 1100, height: 760)
        .commands {
            LumiFactory.makeCommands()
        }

        // ActivityBar 目前使用这个稳定 ID 打开设置窗口；独立进程中可安全复用。
        Window("设置", id: AppBootstrap.settingsWindowID) {
            LumiFactory.makeSettingsWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 780, height: 600)
    }
}