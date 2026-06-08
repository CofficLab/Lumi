import SwiftUI

struct AppCommands: Commands {
    var body: some Commands {
        SidebarCommands()
        DebugCommand()
        SettingsCommand()
        WindowCommand()
    }
}
