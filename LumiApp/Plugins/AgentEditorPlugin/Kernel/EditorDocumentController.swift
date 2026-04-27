import AppKit
import Foundation
import LanguageServerProtocol

final class EditorDocumentController {
    private(set) var buffer: EditorBuffer?
    private(set) var textStorage: NSTextStorage?

    var currentText: String? {
        buffer?.text ?? textStorage?.string
    }

    func clear() {
        buffer = nil
        textStorage = nil
    }

    @discardableResult
    func load(text: String) -> EditorEditResult {
        let buffer = EditorBuffer(text: text)
        self.buffer = buffer
        syncTextStorage(from: buffer.text)
        return EditorEditResult(snapshot: buffer.snapshot(), selections: nil)
    }

    @discardableResult
    func replaceText(_ text: String) -> EditorEditResult {
        let result: EditorEditResult
        if let buffer {
            result = buffer.replaceText(text)
        } else {
            let newBuffer = EditorBuffer(text: text)
            buffer = newBuffer
            result = EditorEditResult(snapshot: newBuffer.snapshot(), selections: nil)
        }
        syncTextStorage(from: result.snapshot.text)
        return result
    }

    @discardableResult
    func apply(transaction: EditorTransaction) -> EditorEditResult? {
        guard let buffer else { return nil }
        let previousText = buffer.text
        guard let result = buffer.apply(transaction) else { return nil }
        guard result.snapshot.text != previousText else { return nil }
        syncTextStorage(from: result.snapshot.text)
        return result
    }

    @discardableResult
    func applyTextEdits(_ edits: [TextEdit]) -> EditorEditResult? {
        guard let text = currentText else { return nil }
        guard let transaction = TextEditTransactionBuilder.makeTransaction(edits: edits, in: text) else {
            return nil
        }
        return apply(transaction: transaction)
    }

    @discardableResult
    func syncBufferFromTextStorageIfNeeded() -> EditorEditResult? {
        guard let textStorage else { return nil }
        guard buffer?.text != textStorage.string else { return nil }
        return replaceText(textStorage.string)
    }

    private func syncTextStorage(from text: String) {
        if let textStorage {
            if textStorage.string != text {
                textStorage.mutableString.setString(text)
            }
        } else {
            textStorage = NSTextStorage(string: text)
        }
    }
}
