import Foundation
import AppKit
import CodeEditSourceEditor
import CodeEditTextView
import LanguageServerProtocol

@MainActor
final class EditorInputRouter {
    func handleTextDidChange(
        state: EditorState?,
        controller: TextViewController,
        currentText: String,
        shouldSuppressReconciliation: Bool,
        bridge: TextViewBridge
    ) {
        if state == nil {
            EditorPlugin.logger.warning("\(EditorState.t)Coordinator 已被释放，state 为 nil")
        }
        if !shouldSuppressReconciliation {
            state?.notifyContentChanged(fromTextViewString: currentText)
        }
        guard let state else { return }

        Task { @MainActor in
            let context = bridge.interactionContext(
                controller: controller,
                state: state,
                typedCharacter: bridge.lastTypedCharacter(in: controller)
            )
            await state.editorExtensions.runInteractionTextDidChange(
                context: context,
                state: state,
                controller: controller
            )
        }
    }

    func handleSelectionDidChange(
        state: EditorState,
        controller: TextViewController,
        selectionRanges: [NSRange],
        cursorPositions: [CursorPosition],
        bridge: TextViewBridge
    ) async {
        state.logMultiCursorInput(
            action: "coordinator.selectionDidChange",
            textViewSelections: selectionRanges,
            note: "cursorPositions=\(cursorPositions.count)"
        )

        let cursorCount = controller.textView?.selectionManager.textSelections.count ?? 0
        let stateCount = state.multiCursorState.all.count
        let isMultiCursorSession = stateCount > 1 || cursorCount > 1

        if !isMultiCursorSession {
            bridge.syncSelections(from: controller, to: state)
            state.clearUnfocusedMultiCursorsIfNeeded()
        }

        let cursor = cursorPositions.first
        state.updateSelectedProblemDiagnostic(for: cursor)
        guard let cursor else { return }

        await refreshCodeActions(
            state: state,
            controller: controller,
            cursor: cursor
        )

        let context = bridge.interactionContext(
            controller: controller,
            state: state,
            typedCharacter: nil
        )
        await state.editorExtensions.runInteractionSelectionDidChange(
            context: context,
            state: state,
            controller: controller
        )
    }

    func handleNativeReplacement(
        state: EditorState?,
        pendingEdit: PendingNativeReplacement,
        textViewString: String
    ) {
        state?.applyNativeTextEdit(
            range: pendingEdit.nsRange,
            text: pendingEdit.text,
            textViewString: textViewString
        )
        state?.notifyLSPIncrementalChange(range: pendingEdit.lspRange, text: pendingEdit.text)
        if let undoState = pendingEdit.undoState {
            state?.recordUndoChange(from: undoState, reason: "text_input")
        }
    }

    private func refreshCodeActions(
        state: EditorState,
        controller: TextViewController,
        cursor: CursorPosition
    ) async {
        if !state.areCodeActionsEnabled {
            state.codeActionProvider.clear()
            return
        }
        guard let fileURL = state.currentFileURL else { return }
        if state.projectLanguagePreflightError(operation: "代码操作") != nil {
            state.codeActionProvider.clear()
            return
        }

        let diagnostics = state.panelState.problemDiagnostics.filter { diag in
            Int(diag.range.start.line) + 1 == cursor.start.line ||
            (Int(diag.range.start.line) + 1 < cursor.start.line && Int(diag.range.end.line) + 1 >= cursor.start.line)
        }
        let selectedText = selectedText(from: controller)

        await state.codeActionProvider.requestCodeActionsForLine(
            uri: fileURL.absoluteString,
            line: max(cursor.start.line - 1, 0),
            character: max(cursor.start.column - 1, 0),
            diagnostics: diagnostics,
            languageId: state.detectedLanguage?.tsName ?? "swift",
            selectedText: selectedText
        )
    }

    private func selectedText(from controller: TextViewController) -> String? {
        guard let textView = controller.textView,
              let selection = textView.selectionManager.textSelections.first else { return nil }
        let range = selection.range
        guard range.location != NSNotFound,
              range.length > 0,
              let swiftRange = Range(range, in: textView.string) else { return nil }
        return String(textView.string[swiftRange])
    }
}

struct PendingNativeReplacement {
    let lspRange: LSPRange
    let nsRange: NSRange
    let text: String
    let undoState: EditorUndoState?
}
