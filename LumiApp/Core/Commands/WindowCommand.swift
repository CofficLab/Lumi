import SwiftUI

/// 窗口命令：提供主窗口创建入口。
///
/// 支持以下功能：
/// - Cmd+Shift+N 创建新窗口
/// - 监听 `openWindowWithRoute` 通知打开指定路由的窗口
struct WindowCommand: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("新建窗口") {
                NotificationCenter.postOpenWindowWithRoute(route: LumiWindowRoute())
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}
