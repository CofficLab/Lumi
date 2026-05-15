import SwiftUI

/// 窗口命令：提供主窗口创建入口。
struct WindowCommand: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("新建窗口") {
                openWindow(
                    id: MainWindowID.main,
                    value: LumiWindowRoute()
                )
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}
