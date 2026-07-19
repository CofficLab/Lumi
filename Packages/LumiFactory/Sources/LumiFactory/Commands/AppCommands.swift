import SwiftUI

/// 应用命令菜单（简化版）
public struct AppCommands: Commands {
    public init() {}

    public var body: some Commands {
        // 基本的文件和编辑菜单
        CommandGroup(replacing: .appInfo) {
            Button("关于 Lumi") {
                // TODO: 显示关于对话框
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button("设置...") {
                // TODO: 打开设置窗口
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}