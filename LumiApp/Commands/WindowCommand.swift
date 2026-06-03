import SwiftUI

/// 窗口命令：提供主窗口创建入口。
///
/// 支持以下功能：
/// - Cmd+Shift+N 创建新窗口
/// - 通过 SwiftUI `openWindow` 交给系统创建主窗口
struct WindowCommand: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("新建窗口") {
                openWindow(id: AppConfig.mainWindowID, value: LumiWindowRoute())
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}
