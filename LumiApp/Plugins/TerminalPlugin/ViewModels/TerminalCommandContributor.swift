import Foundation
import SwiftUI
import MagicKit
import CodeEditTextView

/// 终端命令贡献者
///
/// 提供打开/关闭终端面板的命令，支持快捷键。
@MainActor
final class TerminalCommandContributor: SuperEditorCommandContributor {
    let id: String = "terminal.commands"

    func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        return [
            EditorCommandSuggestion(
                id: "terminal.toggle-panel",
                title: "Toggle Terminal Panel",
                systemImage: "terminal",
                category: "Terminal",
                shortcut: EditorCommandShortcut(key: "t", modifiers: [.command, .control]),
                order: 100,
                isEnabled: true,
                action: {
                    state.panelState.isTerminalPanelPresented.toggle()
                }
            ),
            EditorCommandSuggestion(
                id: "terminal.new-session",
                title: "New Terminal Session",
                systemImage: "plus",
                category: "Terminal",
                shortcut: EditorCommandShortcut(key: "t", modifiers: [.command, .shift]),
                order: 110,
                isEnabled: true,
                action: {
                    // 确保终端面板打开
                    state.panelState.isTerminalPanelPresented = true
                    // 创建新会话
                    let workingDirectory = state.currentFileURL?.deletingLastPathComponent().path
                    TerminalTabsViewModel.shared.createSession(workingDirectory: workingDirectory)
                }
            )
        ]
    }
}