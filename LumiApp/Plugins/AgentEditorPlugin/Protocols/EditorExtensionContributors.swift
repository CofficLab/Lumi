import Foundation
import CodeEditSourceEditor
import CodeEditTextView
import SwiftUI

// MARK: - Completion

/// 编辑器补全上下文
@MainActor
struct EditorCompletionContext {
    let languageId: String
    let line: Int
    let character: Int
    let prefix: String
    let isTypeContext: Bool
}

/// 编辑器补全建议（由扩展提供）
@MainActor
struct EditorCompletionSuggestion: Hashable {
    let label: String
    let insertText: String
    let detail: String?
    let priority: Int
}

/// 编辑器补全扩展点
@MainActor
protocol EditorCompletionContributor: AnyObject {
    var id: String { get }
    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion]
}

// MARK: - Hover

/// 编辑器悬停上下文
@MainActor
struct EditorHoverContext {
    let languageId: String
    let line: Int
    let character: Int
    let symbol: String
}

/// 编辑器悬停建议
@MainActor
struct EditorHoverSuggestion: Hashable {
    let markdown: String
    let priority: Int
}

/// 编辑器悬停扩展点
@MainActor
protocol EditorHoverContributor: AnyObject {
    var id: String { get }
    func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion]
}

// MARK: - Code Action

/// 编辑器代码动作上下文
@MainActor
struct EditorCodeActionContext {
    let languageId: String
    let line: Int
    let character: Int
    let selectedText: String?
}

/// 编辑器代码动作建议
@MainActor
struct EditorCodeActionSuggestion: Hashable {
    let id: String
    let title: String
    let command: String
    let priority: Int
}

/// 编辑器代码动作扩展点
@MainActor
protocol EditorCodeActionContributor: AnyObject {
    var id: String { get }
    func provideCodeActions(context: EditorCodeActionContext) async -> [EditorCodeActionSuggestion]
}

// MARK: - Command

/// 编辑器命令上下文
@MainActor
struct EditorCommandContext {
    let languageId: String
    let hasSelection: Bool
    let line: Int
    let character: Int
}

/// 编辑器命令建议
@MainActor
struct EditorCommandSuggestion: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let order: Int
    let isEnabled: Bool
    let action: () -> Void
}

/// 编辑器命令扩展点
@MainActor
protocol EditorCommandContributor: AnyObject {
    var id: String { get }
    func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion]
}

// MARK: - Side Panel

/// 编辑器侧边面板建议（如 References / Problems）
@MainActor
struct EditorSidePanelSuggestion: Identifiable {
    let id: String
    let order: Int
    let isPresented: (EditorState) -> Bool
    let content: (EditorState) -> AnyView
}

/// 编辑器侧边面板扩展点
@MainActor
protocol EditorSidePanelContributor: AnyObject {
    var id: String { get }
    func provideSidePanels(state: EditorState) -> [EditorSidePanelSuggestion]
}

// MARK: - Sheet

/// 编辑器弹窗建议（Sheet）
@MainActor
struct EditorSheetSuggestion: Identifiable {
    let id: String
    let order: Int
    let isPresented: (EditorState) -> Bool
    let onDismiss: (EditorState) -> Void
    let content: (EditorState) -> AnyView
}

/// 编辑器弹窗扩展点（Sheet）
@MainActor
protocol EditorSheetContributor: AnyObject {
    var id: String { get }
    func provideSheets(state: EditorState) -> [EditorSheetSuggestion]
}

// MARK: - Toolbar

/// 编辑器工具栏项建议
@MainActor
struct EditorToolbarItemSuggestion: Identifiable {
    enum Placement {
        case center
        case trailing
    }

    let id: String
    let order: Int
    let placement: Placement
    let content: (EditorState) -> AnyView
}

/// 编辑器工具栏扩展点
@MainActor
protocol EditorToolbarContributor: AnyObject {
    var id: String { get }
    func provideToolbarItems(state: EditorState) -> [EditorToolbarItemSuggestion]
}

// MARK: - Interaction

/// 编辑器交互上下文（文本/选区变化）
@MainActor
struct EditorInteractionContext {
    let languageId: String
    let line: Int
    let character: Int
    let typedCharacter: String?
}

/// 编辑器交互扩展点
@MainActor
protocol EditorInteractionContributor: AnyObject {
    var id: String { get }
    func onTextDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async
    func onSelectionDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async
}

extension EditorInteractionContributor {
    func onTextDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async {}

    func onSelectionDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async {}
}
