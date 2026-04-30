import Foundation
import AppKit
import CodeEditSourceEditor
import CodeEditTextView
import LanguageServerProtocol

@MainActor
final class TextViewBridge {
    private struct PendingNativeEdit {
        let lspRange: LSPRange
        let nsRange: NSRange
        let undoState: EditorUndoState?
    }

    private var pendingNativeEdit: PendingNativeEdit?
    private var suppressNextTextDidChangeReconciliation = false

    func attach(
        controller: TextViewController,
        state: EditorState?,
        jumpDelegate: EditorJumpToDefinitionDelegate?,
        existingObserver: NSObjectProtocol?
    ) -> NSObjectProtocol {
        if let existingObserver {
            NotificationCenter.default.removeObserver(existingObserver)
        }

        jumpDelegate?.textViewController = controller
        state?.focusedTextView = controller.textView

        return NotificationCenter.default.addObserver(
            forName: NSText.didEndEditingNotification,
            object: controller.textView,
            queue: .main
        ) { [weak state] _ in
            Task { @MainActor [weak state] in
                state?.saveNowIfNeeded(reason: "editor_focus_lost")
            }
        }
    }

    func detach(
        state: EditorState?,
        observer: NSObjectProtocol?
    ) {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        pendingNativeEdit = nil
        suppressNextTextDidChangeReconciliation = false
        state?.focusedTextView = nil
    }

    func teardown(
        state: inout EditorState?,
        textViewController: inout TextViewController?,
        observer: inout NSObjectProtocol?
    ) {
        let currentState = state
        let currentObserver = observer
        state = nil
        textViewController = nil
        observer = nil
        detach(state: currentState, observer: currentObserver)
    }

    func consumeSuppressNextTextDidChangeReconciliation() -> Bool {
        let shouldSuppress = suppressNextTextDidChangeReconciliation
        suppressNextTextDidChangeReconciliation = false
        return shouldSuppress
    }

    func beginNativeReplacement(
        range: NSRange,
        text: String,
        in textView: TextView,
        captureUndoState: () -> EditorUndoState?
    ) -> Bool {
        guard let lspRange = lspRange(from: range, in: textView.string) else {
            pendingNativeEdit = nil
            return false
        }

        _ = text
        pendingNativeEdit = PendingNativeEdit(
            lspRange: lspRange,
            nsRange: range,
            undoState: captureUndoState()
        )
        return true
    }

    func consumeNativeReplacement(text: String) -> PendingNativeReplacement? {
        guard let pendingNativeEdit else { return nil }
        self.pendingNativeEdit = nil
        suppressNextTextDidChangeReconciliation = true
        return PendingNativeReplacement(
            lspRange: pendingNativeEdit.lspRange,
            nsRange: pendingNativeEdit.nsRange,
            text: text,
            undoState: pendingNativeEdit.undoState
        )
    }

    func syncSelections(
        from controller: TextViewController,
        to state: EditorState
    ) {
        guard let textView = controller.textView else { return }

        let currentCanonical = state.canonicalSelectionSet
        guard let viewSelectionSet = EditorSelectionMapper.toCanonical(
            from: textView,
            currentState: currentCanonical
        ) else { return }

        guard EditorSelectionMapper.shouldAcceptCanonicalUpdate(
            viewSelections: viewSelectionSet,
            currentState: currentCanonical
        ) else { return }

        state.applyCanonicalSelectionSet(viewSelectionSet)
    }

    func interactionContext(
        controller: TextViewController,
        state: EditorState,
        typedCharacter: String?
    ) -> EditorInteractionContext {
        let textView = controller.textView
        let text = textView?.string ?? ""
        let selection = textView?.selectionManager.textSelections.first?.range ?? NSRange(location: 0, length: 0)
        let offset = max(selection.location, 0)
        let position = lspPosition(utf16Offset: offset, in: text)
            ?? Position(line: max(state.cursorLine - 1, 0), character: max(state.cursorColumn - 1, 0))

        return EditorInteractionContext(
            languageId: state.detectedLanguage?.tsName ?? "swift",
            line: Int(position.line),
            character: Int(position.character),
            typedCharacter: typedCharacter
        )
    }

    func lastTypedCharacter(in controller: TextViewController) -> String? {
        guard let textView = controller.textView else { return nil }
        let text = textView.string as NSString
        guard let selection = textView.selectionManager.textSelections.first else { return nil }
        let location = selection.range.location
        guard location != NSNotFound, location > 0, location <= text.length else { return nil }
        return text.substring(with: NSRange(location: location - 1, length: 1))
    }

    func lspRange(from nsRange: NSRange, in text: String) -> LSPRange? {
        let utf16Count = text.utf16.count
        let startOffset = nsRange.location
        let endOffset = nsRange.location + nsRange.length

        guard startOffset >= 0, endOffset >= startOffset, endOffset <= utf16Count else {
            return nil
        }

        guard let start = lspPosition(utf16Offset: startOffset, in: text),
              let end = lspPosition(utf16Offset: endOffset, in: text) else {
            return nil
        }

        return LSPRange(start: start, end: end)
    }

    func lspPosition(utf16Offset: Int, in text: String) -> Position? {
        guard utf16Offset >= 0, utf16Offset <= text.utf16.count else { return nil }

        var line = 0
        var character = 0
        var consumed = 0

        for unit in text.utf16 {
            if consumed >= utf16Offset {
                break
            }
            if unit == 0x0A {
                line += 1
                character = 0
            } else {
                character += 1
            }
            consumed += 1
        }

        return Position(line: line, character: character)
    }
}
