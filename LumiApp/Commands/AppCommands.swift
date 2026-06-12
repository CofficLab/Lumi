import SwiftUI

struct AppCommands: Commands {
    var body: some Commands {
        SidebarCommands()
        ChatCommands()
        DebugCommand()
        CheckForUpdatesCommand()
        SettingsCommand()
        WindowCommand()
    }
}
