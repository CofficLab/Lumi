import AppUpdatePlugin
import LumiFactory
import SwiftUI

@main
struct LumiApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: MacAgent

    /// Lumi 直营分发：显式注入 `AppUpdatePlugin`（Sparkle 自动更新）。
    /// 该插件不再由 `LumiFactory` 静态引用，因此上架 Mac App Store 的
    /// 独立 app 可以在不链接 Sparkle 的前提下复用同一套 `LumiFactory` 骨架。
    private static let hostConfiguration = LumiHostConfiguration(
        additionalPlugins: [AppUpdatePlugin()]
    )

    var body: some Scene {
        WindowGroup(AppBootstrap.appName, id: AppBootstrap.mainWindowID) {
            LumiFactory.makeMainWindow(configuration: Self.hostConfiguration)
                .environmentObject(appDelegate)
                .onReceive(appDelegate.$pendingOpenPath.compactMap { $0 }) { path in
                    OpenProjectHandler.shared.requestOpen(path: path)
                    appDelegate.pendingOpenPath = nil

                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
                            window.makeKeyAndOrderFront(nil)
                        }
                    }
                }
        }
        .handlesExternalEvents(matching: Set())
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: AppBootstrap.defaultWindowSize.width, height: AppBootstrap.defaultWindowSize.height)
        .commands {
            LumiFactory.makeCommands()
        }

        Window("设置", id: AppBootstrap.settingsWindowID) {
            LumiFactory.makeSettingsWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(
            width: AppBootstrap.defaultSettingsWindowSize.width,
            height: AppBootstrap.defaultSettingsWindowSize.height
        )
    }
}
