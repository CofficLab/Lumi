import SwiftUI

struct WindowCommand: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("新建窗口") {
                openWindow(id: AppBootstrap.mainWindowID)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}
