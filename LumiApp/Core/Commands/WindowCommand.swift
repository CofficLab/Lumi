import SwiftUI

/// 窗口命令：提供主窗口创建入口。
///
/// 支持以下功能：
/// - Cmd+Shift+N 创建新窗口
/// - 监听 `openWindowWithRoute` 通知打开指定路由的窗口
struct WindowCommand: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("新建窗口") {
                openWindow(
                    id: AppConfig.mainWindowID,
                    value: LumiWindowRoute()
                )
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .onReceive(NotificationCenter.default.publisher(for: .openWindowWithRoute)) { notification in
                if let route = notification.userInfo?["route"] as? LumiWindowRoute {
                    openWindow(id: AppConfig.mainWindowID, value: route)
                }
            }
        }
    }
}
