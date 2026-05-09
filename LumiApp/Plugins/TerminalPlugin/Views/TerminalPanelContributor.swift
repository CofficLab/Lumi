import Foundation
import SwiftUI
import MagicKit

/// 终端面板贡献者
///
/// 注册终端面板到编辑器底部面板区域，实现类似 VSCode 的终端 Tab。
@MainActor
final class TerminalPanelContributor: SuperEditorPanelContributor {
    let id: String = "terminal.panel"

    init() {}

    func providePanels(state: EditorState) -> [EditorPanelSuggestion] {
        // 终端面板始终可显示（不依赖语言或文件类型）
        return [
            EditorPanelSuggestion(
                id: "terminal-bottom-panel",
                title: "Terminal",
                systemImage: "terminal",
                placement: .bottom,
                order: 100,  // 排在内置面板之后
                isPresented: { state in
                    state.panelState.isTerminalPanelPresented
                },
                onDismiss: { state in
                    state.panelState.isTerminalPanelPresented = false
                },
                content: { state in
                    // 使用当前文件所在目录作为工作目录
                    let workingDirectory = state.currentFileURL?.deletingLastPathComponent().path
                    return AnyView(BottomTerminalPanelView(workingDirectory: workingDirectory))
                }
            )
        ]
    }
}