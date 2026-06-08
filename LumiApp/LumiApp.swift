import SwiftUI

@main
struct LumiApp: App {
    var body: some Scene {
        WindowGroup(AppBootstrap.appName, id: AppBootstrap.mainWindowID) {
            MainWindowSceneContent()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: AppBootstrap.defaultWindowSize.width, height: AppBootstrap.defaultWindowSize.height)
        .commands {
            AppCommands()
        }

        Window("设置", id: AppBootstrap.settingsWindowID) {
            SettingsSceneContent()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(
            width: AppBootstrap.defaultSettingsWindowSize.width,
            height: AppBootstrap.defaultSettingsWindowSize.height
        )
    }
}
