import Foundation
import EditorService
import EditorCodeEditTextView

@MainActor
public final class MultiCursorCommandContributor: SuperEditorCommandContributor {
    public let id: String = "builtin.editor.multi-cursor-commands"

    public func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        let hasSelection = context.hasSelection

        return [
            .init(
                id: "builtin.add-next-occurrence",
                title: String(localized: "Add Next Occurrence", bundle: .module),
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
                title: String(localized: "Remove Last Occurrence Selection", bundle: .module),
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
                title: String(localized: "Select All Occurrences", bundle: .module),
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
                title: String(localized: "Clear Additional Cursors", bundle: .module),
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
