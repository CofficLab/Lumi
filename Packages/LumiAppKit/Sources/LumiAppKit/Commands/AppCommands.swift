import SwiftUI

public struct AppCommands: Commands {
    public init() {}

    public var body: some Commands {
        SidebarCommands()
        EditorSaveCommands()
        ChatCommands()
        DebugCommand()
        CheckForUpdatesCommand()
        SettingsCommand()
        WindowCommand()
    }
}
