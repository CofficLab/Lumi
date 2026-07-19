import LumiKernel
import SwiftUI

/// 应用命令菜单
///
/// 从 LumiKernel 获取插件注册的命令并渲染。
public struct AppCommands: Commands {
    let kernel: LumiKernel

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some Commands {
        // 渲染插件注册的命令组
        ForEach(kernel.allCommandGroups) { group in
            CommandGroup(named: group.name) {
                ForEach(group.items) { item in
                    Button(item.title) {
                        item.action()
                    }
                    .keyboardShortcutIfAvailable(item.shortcut, modifiers: item.modifiers)
                }
            }
        }

        // 默认命令
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

// MARK: - Keyboard Shortcut Extension

private extension Button {
    func keyboardShortcutIfAvailable(
        _ key: KeyEquivalent?,
        modifiers: EventModifiers?
    ) -> some View {
        if let key, let modifiers {
            return self.keyboardShortcut(key, modifiers: modifiers).asAnyView()
        } else if let key {
            return self.keyboardShortcut(key).asAnyView()
        } else {
            return self.asAnyView()
        }
    }
}

private extension View {
    func asAnyView() -> AnyView {
        AnyView(self)
    }
}