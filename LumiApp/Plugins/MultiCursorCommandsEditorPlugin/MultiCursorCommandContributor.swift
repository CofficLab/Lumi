import Foundation
import CodeEditTextView

@MainActor
final class MultiCursorCommandContributor: SuperEditorCommandContributor {
    let id: String = "builtin.editor.multi-cursor-commands"

    func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        let hasSelection = context.hasSelection

        return [
            .init(
                id: "builtin.add-next-occurrence",
                title: String(localized: "Add Next Occurrence", table: "LumiEditor"),
                systemImage: "plus.magnifyingglass",
                category: EditorCommandCategory.multiCursor.rawValue,
                order: 51,
                isEnabled: hasSelection
            ) {
                guard let textView else { return }
                let currentSelection = textView.selectionManager.textSelections.last?.range ?? NSRange(location: NSNotFound, length: 0)
                if let ranges = state.addNextOccurrence(from: currentSelection) {
                    textView.selectionManager.setSelectedRanges(ranges)
                }
            },

            .init(
                id: "builtin.remove-last-occurrence-selection",
                title: String(localized: "Remove Last Occurrence Selection", table: "LumiEditor"),
                systemImage: "minus.magnifyingglass",
                category: EditorCommandCategory.multiCursor.rawValue,
                order: 52,
                isEnabled: state.multiCursorState.isEnabled
            ) {
                guard let textView else { return }
                if let ranges = state.removeLastOccurrenceSelection() {
                    textView.selectionManager.setSelectedRanges(ranges)
                }
            },

            .init(
                id: "builtin.select-all-occurrences",
                title: String(localized: "Select All Occurrences", table: "LumiEditor"),
                systemImage: "text.magnifyingglass",
                category: EditorCommandCategory.multiCursor.rawValue,
                order: 53,
                isEnabled: hasSelection
            ) {
                guard let textView else { return }
                let currentSelection = textView.selectionManager.textSelections.last?.range ?? NSRange(location: NSNotFound, length: 0)
                if let ranges = state.addAllOccurrences(from: currentSelection) {
                    textView.selectionManager.setSelectedRanges(ranges)
                }
            },

            .init(
                id: "builtin.clear-additional-cursors",
                title: String(localized: "Clear Additional Cursors", table: "LumiEditor"),
                systemImage: "cursorarrow.motionlines",
                category: EditorCommandCategory.multiCursor.rawValue,
                order: 54,
                isEnabled: state.multiCursorState.isEnabled
            ) {
                state.clearMultiCursors()
            },
        ]
    }
}
