import Foundation
import AppKit
import EditorSource
import EditorTextView
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
        if let client = controller.treeSitterClient {
            jumpDelegate?.treeSitterClient = client
        }
        state?.focusedTextView = controller.textView

        return NotificationCenter.default.addObserver(
            forName: NSText.didEndEditingNotification,
            object: controller.textView,
            queue: .main
        ) { [weak state] _ in
            Task { @MainActor [weak state] in
                // 编辑器失焦时自动保存。
                // 语义对齐 VS Code：
                // - onFocusChange / onWindowChange：失焦保存
                // - afterDelay / off：失焦不保存（afterDelay 的保存由防抖调度器负责）
                guard let state, state.autoSaveMode.respondsToFocusChange else { return }
                state.triggerAutoSave(reason: "editor_focus_lost")
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
        guard let selection = textView.selectionManager.textSelections.first else { return nil }
        return Self.lastCharacter(before: selection.range.location, in: textView.string)
    }

    static func lastCharacter(before location: Int, in text: String) -> String? {
        let nsText = text as NSString
        guard location != NSNotFound, location > 0, location <= nsText.length else { return nil }
        let characterRange = nsText.rangeOfComposedCharacterSequence(at: location - 1)
        guard characterRange.location != NSNotFound,
              characterRange.location >= 0,
              characterRange.max <= nsText.length else { return nil }
        return nsText.substring(with: characterRange)
    }

    func lspRange(from nsRange: NSRange, in text: String) -> LSPRange? {
        let utf16Count = text.utf16.count
        let startOffset = nsRange.location
        let endResult = nsRange.location.addingReportingOverflow(nsRange.length)

        guard !endResult.overflow else {
            return nil
        }

        let endOffset = endResult.partialValue

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
