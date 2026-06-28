import Foundation
import SuperLogKit
import EditorService
import SwiftUI
import LumiCoreKit

/// Vue 命令贡献器
///
/// 提供 SFC 区块导航命令：
/// - Go to Template (⌘+1)
/// - Go to Script (⌘+2)
/// - Go to Style (⌘+3)
@MainActor
final class VueCommandContributor: SuperEditorCommandContributor, SuperLog {
    let id = "vue.commands"

    func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        guard context.languageId == "vue" else { return [] }

        return [
            goToTemplateCommand(state: state),
            goToScriptCommand(state: state),
            goToStyleCommand(state: state),
        ]
    }

    // MARK: - Go to Template

    private func goToTemplateCommand(state: EditorState) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "vue.goToTemplate",
            title: LumiPluginLocalization.string("Go to Template", bundle: .module),
            systemImage: "anglebrackets.left",
            category: LumiPluginLocalization.string("Vue", bundle: .module),
            shortcut: EditorCommandShortcut(key: "1", modifiers: [.command]),
            order: 100,
            isEnabled: true
        ) { [weak self, weak state] in
            guard let self, let state else { return }
            self.navigateToBlock(.template, state: state)
        }
    }

    // MARK: - Go to Script

    private func goToScriptCommand(state: EditorState) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "vue.goToScript",
            title: LumiPluginLocalization.string("Go to Script", bundle: .module),
            systemImage: "curlybraces",
            category: LumiPluginLocalization.string("Vue", bundle: .module),
            shortcut: EditorCommandShortcut(key: "2", modifiers: [.command]),
            order: 200,
            isEnabled: true
        ) { [weak self, weak state] in
            guard let self, let state else { return }
            self.navigateToBlock(.script, state: state)
        }
    }

    // MARK: - Go to Style

    private func goToStyleCommand(state: EditorState) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: "vue.goToStyle",
            title: LumiPluginLocalization.string("Go to Style", bundle: .module),
            systemImage: "paintbrush",
            category: LumiPluginLocalization.string("Vue", bundle: .module),
            shortcut: EditorCommandShortcut(key: "3", modifiers: [.command]),
            order: 300,
            isEnabled: true
        ) { [weak self, weak state] in
            guard let self, let state else { return }
            self.navigateToBlock(.style, state: state)
        }
    }

    // MARK: - Navigation

    /// 导航到指定区块的起始位置
    private func navigateToBlock(_ blockType: SFCBlockType, state: EditorState) {
        guard let text = state.content?.string else { return }
        let blocks = SFCBlock.parse(from: text)
        guard let block = SFCBlock.find(type: blockType, in: blocks) else { return }

        // 跳转到区块内容的起始行（跳过开标签行）
        let targetLine = min(block.startLine + 1, block.endLine)
        state.cursorLine = targetLine + 1 // cursorLine 是 1-based
        state.cursorColumn = 1

        if EditorVuePlugin.verbose {
            if EditorVuePlugin.verbose {
                            EditorVuePlugin.logger.info("\(EditorVuePlugin.t)导航到 \(blockType.tagName) 区块，行 \(targetLine)")
            }
        }
    }
}
