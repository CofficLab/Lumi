import Foundation

@MainActor
public final class EditorCommandService {
    private let state: EditorState

    init(state: EditorState) {
        self.state = state
    }

    public func performCommand(id: String) {
        state.performEditorCommand(id: id)
    }

    func performCommand(id: String, invocationContext: EditorCommandInvocationContext) {
        state.performEditorCommand(id: id, invocationContext: invocationContext)
    }

    func commandSuggestions() -> [EditorCommandSuggestion] {
        state.editorCommandSuggestions()
    }

    func commandSections(matching query: String = "") -> [EditorCommandSection] {
        state.editorCommandSections(matching: query)
    }

    public func editorCommandPresentationModel(matching query: String = "") -> EditorCommandPresentationModel {
        state.editorCommandPresentationModel(matching: query)
    }

    func editorCommandPresentationModel(
        for invocationContext: EditorCommandInvocationContext,
        matching query: String = "",
        categories: Set<EditorCommandCategory>? = nil
    ) -> EditorCommandPresentationModel {
        state.editorCommandPresentationModel(
            for: invocationContext,
            matching: query,
            categories: categories
        )
    }

    func editorContextMenuPresentationModel(
        for invocationContext: EditorCommandInvocationContext,
        matching query: String = "",
        categories: Set<EditorCommandCategory>? = nil
    ) -> EditorCommandPresentationModel {
        state.editorContextMenuPresentationModel(
            for: invocationContext,
            matching: query,
            categories: categories
        )
    }

    func editorCommandInvocationContext(for textView: TextView?) -> EditorCommandInvocationContext {
        state.editorCommandInvocationContext(for: textView)
    }

    public func preferredCommandPaletteCategory() -> EditorCommandCategory? {
        state.preferredCommandPaletteCategory()
    }

    public func setPreferredCommandPaletteCategory(_ category: EditorCommandCategory?) {
        state.setPreferredCommandPaletteCategory(category)
    }

    public func quickOpenQuery(for rawQuery: String) -> EditorQuickOpenQuery {
        state.quickOpenQuery(for: rawQuery)
    }

    public func editorQuickOpenItems(
        matching query: String,
        openEditors: [EditorOpenEditorItem],
        onOpenFile: @escaping (URL, CursorPosition?, Bool) -> Void
    ) async -> [EditorQuickOpenItemSuggestion] {
        await state.editorQuickOpenItems(
            matching: query,
            openEditors: openEditors,
            onOpenFile: onOpenFile
        )
    }
}
