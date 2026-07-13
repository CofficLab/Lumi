import SwiftUI

@main
struct LumiApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: MacAgent

    var body: some Scene {
        WindowGroup(AppBootstrap.appName, id: AppBootstrap.mainWindowID) {
            MainWindow()
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
            AppCommands()
        }

        Window("设置", id: AppBootstrap.settingsWindowID) {
            WindowSettings()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(
            width: AppBootstrap.defaultSettingsWindowSize.width,
            height: AppBootstrap.defaultSettingsWindowSize.height
        )
    }
}
