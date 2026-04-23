import Foundation
import CodeEditTextView

@MainActor
final class MultiCursorCommandContributor: EditorCommandContributor {
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
                id: "builtin.select-all-occurrences",
                title: String(localized: "Select All Occurrences", table: "LumiEditor"),
                systemImage: "text.magnifyingglass",
                order: 52,
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
                order: 53,
                isEnabled: state.multiCursorState.isEnabled
            ) {
                state.clearMultiCursors()
            },
        ]
    }
}
