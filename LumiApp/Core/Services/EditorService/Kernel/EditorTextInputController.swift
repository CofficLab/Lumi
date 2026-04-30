import Foundation

@MainActor
final class EditorTextInputController {
    struct InputEditPlan {
        let replacementRange: NSRange
        let replacementText: String
        let selectedRanges: [NSRange]
        let reason: String
    }

    func textInputPlan(
        text: String,
        replacementRange: NSRange,
        textViewSelections: [NSRange],
        multiCursorSelectionCount: Int,
        currentText: String,
        languageId: String
    ) -> InputEditPlan? {
        if multiCursorSelectionCount <= 1,
           text.count == 1,
           let typedChar = text.first,
           let selection = singleInputSelectionRange(
                from: textViewSelections,
                replacementRange: replacementRange
           ) {
            let config = BracketPairsConfig.defaultForLanguage(languageId)
            if let edit = BracketMatcher.autoClosingEdit(
                in: currentText,
                selection: selection,
                typedChar: typedChar,
                config: config
            ) {
                return InputEditPlan(
                    replacementRange: edit.replacementRange,
                    replacementText: edit.replacementText,
                    selectedRanges: [edit.selectedRange],
                    reason: "bracket_auto_closing"
                )
            }
        }

        if multiCursorSelectionCount > 1,
           text.count == 1,
           let typedChar = text.first,
           let edit = multiCursorAutoClosingEdit(
                in: currentText,
                selections: textViewSelections,
                typedChar: typedChar,
                config: BracketPairsConfig.defaultForLanguage(languageId)
           ) {
            return InputEditPlan(
                replacementRange: NSRange(location: 0, length: (currentText as NSString).length),
                replacementText: edit.text,
                selectedRanges: edit.selections,
                reason: "multi_cursor_bracket_auto_closing"
            )
        }

        return nil
    }

    func insertNewlinePlan(
        textViewSelections: [NSRange],
        multiCursorSelectionCount: Int,
        currentText: String,
        tabSize: Int,
        useSpaces: Bool
    ) -> InputEditPlan? {
        guard multiCursorSelectionCount <= 1 else { return nil }
        guard let selection = singleInputSelectionRange(
            from: textViewSelections,
            replacementRange: NSRange(location: NSNotFound, length: 0)
        ) else {
            return nil
        }

        let result = SmartIndentHandler.handleEnter(
            in: currentText,
            at: selection.location,
            tabSize: tabSize,
            useSpaces: useSpaces
        )

        return InputEditPlan(
            replacementRange: selection,
            replacementText: result.textToInsert,
            selectedRanges: [NSRange(location: selection.location + result.cursorOffset, length: 0)],
            reason: "smart_indent_enter"
        )
    }

    func insertTabPlan(
        textViewSelections: [NSRange],
        multiCursorSelectionCount: Int,
        currentText: String,
        tabSize: Int,
        useSpaces: Bool
    ) -> InputEditPlan? {
        guard multiCursorSelectionCount <= 1 else { return nil }
        guard let selection = singleInputSelectionRange(
            from: textViewSelections,
            replacementRange: NSRange(location: NSNotFound, length: 0)
        ) else {
            return nil
        }

        if selection.length > 0 {
            guard let result = SmartIndentHandler.handleTab(
                in: currentText,
                selection: selection,
                tabSize: tabSize,
                useSpaces: useSpaces
            ) else {
                return nil
            }

            return InputEditPlan(
                replacementRange: result.replacementRange,
                replacementText: result.replacementText,
                selectedRanges: [result.selectedRange],
                reason: "smart_outdent"
            )
        }

        let result = SmartIndentHandler.handleTab(
            at: selection.location,
            hasSelection: false,
            selectionStart: selection.location,
            selectionEnd: selection.location,
            tabSize: tabSize,
            useSpaces: useSpaces
        )

        return InputEditPlan(
            replacementRange: selection,
            replacementText: result.textToInsert,
            selectedRanges: [NSRange(location: selection.location + result.cursorOffset, length: 0)],
            reason: "smart_indent_enter"
        )
    }

    func insertBacktabPlan(
        textViewSelections: [NSRange],
        multiCursorSelectionCount: Int,
        currentText: String,
        tabSize: Int,
        useSpaces: Bool
    ) -> InputEditPlan? {
        guard multiCursorSelectionCount <= 1 else { return nil }
        guard let selection = singleInputSelectionRange(
            from: textViewSelections,
            replacementRange: NSRange(location: NSNotFound, length: 0)
        ) else {
            return nil
        }

        guard let result = SmartIndentHandler.handleBacktab(
            in: currentText,
            selection: selection,
            tabSize: tabSize,
            useSpaces: useSpaces
        ) else {
            return nil
        }

        return InputEditPlan(
            replacementRange: result.replacementRange,
            replacementText: result.replacementText,
            selectedRanges: [result.selectedRange],
            reason: "smart_outdent"
        )
    }

    private func singleInputSelectionRange(
        from selections: [NSRange],
        replacementRange: NSRange
    ) -> NSRange? {
        if replacementRange.location != NSNotFound {
            return replacementRange
        }
        guard selections.count == 1 else { return nil }
        return selections.first
    }

    private func multiCursorAutoClosingEdit(
        in text: String,
        selections: [NSRange],
        typedChar: Character,
        config: BracketPairsConfig
    ) -> (text: String, selections: [NSRange])? {
        guard !selections.isEmpty else { return nil }

        var mutableText = text
        let orderedSelections = selections
            .filter { $0.location != NSNotFound }
            .sorted { $0.location > $1.location }

        var updatedSelectionsDescending: [NSRange] = []
        var applied = false

        for selection in orderedSelections {
            guard let edit = BracketMatcher.autoClosingEdit(
                in: mutableText,
                selection: selection,
                typedChar: typedChar,
                config: config
            ) else {
                return nil
            }

            guard let stringRange = Range(edit.replacementRange, in: mutableText) else {
                return nil
            }

            mutableText.replaceSubrange(stringRange, with: edit.replacementText)
            updatedSelectionsDescending.append(edit.selectedRange)

            if edit.replacementRange.length > 0 || !edit.replacementText.isEmpty || edit.selectedRange != selection {
                applied = true
            }
        }

        guard applied else { return nil }
        return (mutableText, updatedSelectionsDescending.reversed())
    }
}
