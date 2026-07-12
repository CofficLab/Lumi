import Foundation
import EditorService
import LumiCoreKit

/// 编辑器导航右键菜单命令贡献者。
///
/// 在编辑器的右键菜单中提供以下导航命令：
/// - 跳转到定义（Go to Definition）
/// - 跳转到声明（Go to Declaration）
/// - 跳转到类型定义（Go to Type Definition）
/// - 跳转到实现（Go to Implementation）
/// - 查找所有引用（Find All References）
/// - Peek Definition
/// - Peek References
///
/// 这些命令最终由 `ContextMenuCoordinator` 注入到 `NSMenu` 中。
@MainActor
public final class NavigationContextMenuCommandContributor: SuperEditorCommandContributor {
    public let id: String = "builtin.navigation.context-menu"

    public func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        guard textView != nil else { return [] }

        // 使用当前选区作为跳转的起点；如果没有选区，使用光标位置
        let selection = textView?.selectionManager.textSelections.first?.range
            ?? NSRange(location: 0, length: 0)

        return [
            .init(
                id: "builtin.go-to-definition",
                title: LumiPluginLocalization.string("Go to Definition", bundle: .module),
                systemImage: "arrow.turn.down.left",
                category: EditorCommandCategory.navigation.rawValue,
                order: 20,
                isEnabled: true,
                action: {
                    Task { @MainActor in
                        await state.goToDefinition(for: selection)
                    }
                }
            ),
            .init(
                id: "builtin.peek-definition",
                title: LumiPluginLocalization.string("Peek Definition", bundle: .module),
                systemImage: "eye",
                category: EditorCommandCategory.navigation.rawValue,
                order: 25,
                isEnabled: state.canPreview,
                action: {
                    Task { @MainActor in
                        await state.showPeekDefinitionFromCurrentCursor()
                    }
                }
            ),
            .init(
                id: "builtin.go-to-declaration",
                title: LumiPluginLocalization.string("Go to Declaration", bundle: .module),
                systemImage: "doc.badge.plus",
                category: EditorCommandCategory.navigation.rawValue,
                order: 30,
                isEnabled: true,
                action: {
                    Task { @MainActor in
                        await state.goToDeclaration(for: selection)
                    }
                }
            ),
            .init(
                id: "builtin.go-to-type-definition",
                title: LumiPluginLocalization.string("Go to Type Definition", bundle: .module),
                systemImage: "square.on.square",
                category: EditorCommandCategory.navigation.rawValue,
                order: 40,
                isEnabled: true,
                action: {
                    Task { @MainActor in
                        await state.goToTypeDefinition(for: selection)
                    }
                }
            ),
            .init(
                id: "builtin.go-to-implementation",
                title: LumiPluginLocalization.string("Go to Implementation", bundle: .module),
                systemImage: "arrowtriangle.right",
                category: EditorCommandCategory.navigation.rawValue,
                order: 50,
                isEnabled: true,
                action: {
                    Task { @MainActor in
                        await state.goToImplementation(for: selection)
                    }
                }
            ),
            .init(
                id: "builtin.find-references",
                title: LumiPluginLocalization.string("Find All References", bundle: .module),
                systemImage: "link",
                category: EditorCommandCategory.navigation.rawValue,
                order: 60,
                isEnabled: state.canPreview,
                action: {
                    Task { @MainActor in
                        await state.showReferencesFromCurrentCursor()
                    }
                }
            ),
            .init(
                id: "builtin.peek-references",
                title: LumiPluginLocalization.string("Peek References", bundle: .module),
                systemImage: "arrow.triangle.branch",
                category: EditorCommandCategory.navigation.rawValue,
                order: 65,
                isEnabled: state.canPreview,
                action: {
                    Task { @MainActor in
                        await state.showPeekReferencesFromCurrentCursor()
                    }
                }
            ),
        ]
    }
}