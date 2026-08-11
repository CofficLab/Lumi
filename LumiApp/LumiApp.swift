import AppUpdatePlugin
import FactoryCore
import FactoryLumi
import ProjectRAGPlugin
import SwiftUI

@main
struct LumiApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: MacAgent

    /// Lumi 直营分发：显式注入分发渠道敏感或体积较大的插件。
    /// - `AppUpdatePlugin`（Sparkle 自动更新）：MAS 禁止自带更新机制。
    /// - `ProjectRAGPlugin`（vec0.dylib 向量检索）：嵌入的二进制库需要
    ///   特殊代码签名，且 RAG 仅 Lumi 需要；独立 app 不应打包它。
    /// 这些插件不进 FactoryLumi 的完整目录，由 LumiApp 在此显式注入，
    /// 因此上架 Mac App Store 的独立 app 不会链接它们。
    private static let additionalPlugins: [any LumiPlugin] = [
        AppUpdatePlugin(),
        ProjectRAGPlugin(),
    ]

    var body: some Scene {
        WindowGroup(AppBootstrap.appName, id: AppBootstrap.mainWindowID) {
            FactoryLumi.makeMainWindow(additionalPlugins: Self.additionalPlugins)
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
            FactoryLumi.makeCommands()
        }

        Window("设置", id: AppBootstrap.settingsWindowID) {
            FactoryLumi.makeSettingsWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(
            width: AppBootstrap.defaultSettingsWindowSize.width,
            height: AppBootstrap.defaultSettingsWindowSize.height
        )
    }
}
