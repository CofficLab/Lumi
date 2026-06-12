import SwiftUI

struct SettingsCommand: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("设置...") {
                openWindow(id: AppBootstrap.settingsWindowID)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
