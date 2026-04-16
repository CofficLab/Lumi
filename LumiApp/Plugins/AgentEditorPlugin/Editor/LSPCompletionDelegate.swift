import Foundation
import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView
import LanguageServerProtocol

@MainActor
final class LSPCompletionDelegate: NSObject, CodeSuggestionDelegate {

    weak var lspCoordinator: LSPCoordinator?
    weak var editorState: EditorState?

    private var activeItems: [any CodeEditSourceEditor.CodeSuggestionEntry] = []
    private var requestAnchor: CursorPosition?
    private var requestAnchorOffset: Int?

    func completionTriggerCharacters() -> Set<String> {
        let characters = lspCoordinator?.completionTriggerCharacters() ?? []
        return characters.isEmpty ? ["."] : characters
    }

    func completionSuggestionsRequested(
        textView: TextViewController,
        cursorPosition: CursorPosition
    ) async -> (windowPosition: CursorPosition, items: [any CodeEditSourceEditor.CodeSuggestionEntry])? {
        guard let coordinator = lspCoordinator else { return nil }
        guard let editorTextView = textView.textView else { return nil }

        let line = max(cursorPosition.start.line - 1, 0)
        let character = max(cursorPosition.start.column - 1, 0)
        let completionItems = await coordinator.requestCompletion(line: line, character: character)
        let entries = completionItems.map(EditorCodeSuggestionEntry.init(item:))
        guard !entries.isEmpty else { return nil }

        let content = editorTextView.string
        requestAnchor = cursorPosition
        requestAnchorOffset = Self.utf16Offset(for: cursorPosition.start, in: content)
        activeItems = entries
        return (cursorPosition, entries)
    }

    func completionOnCursorMove(
        textView: TextViewController,
        cursorPosition: CursorPosition
    ) -> [any CodeEditSourceEditor.CodeSuggestionEntry]? {
        guard !activeItems.isEmpty else { return nil }
        guard let anchor = requestAnchor else { return nil }
        guard let editorTextView = textView.textView else { return nil }
        if cursorPosition.start.line != anchor.start.line ||
            cursorPosition.start.column < anchor.start.column {
            return nil
        }

        guard let anchorOffset = requestAnchorOffset,
              let cursorOffset = Self.utf16Offset(for: cursorPosition.start, in: editorTextView.string),
              cursorOffset >= anchorOffset else {
            return activeItems
        }

        let content = editorTextView.string as NSString
        let prefixLength = cursorOffset - anchorOffset
        guard prefixLength > 0 else { return activeItems }
        let prefix = content.substring(with: NSRange(location: anchorOffset, length: prefixLength)).lowercased()

        let filtered = activeItems.compactMap { item -> (any CodeEditSourceEditor.CodeSuggestionEntry)? in
            guard let entry = item as? EditorCodeSuggestionEntry else { return item }
            let matches = entry.label.lowercased().hasPrefix(prefix) ||
                entry.filterText?.lowercased().hasPrefix(prefix) == true
            return matches ? item : nil
        }
        return filtered.isEmpty ? nil : filtered
    }

    func completionWindowDidClose() {
        activeItems.removeAll()
        requestAnchor = nil
        requestAnchorOffset = nil
    }

    func completionWindowApplyCompletion(
        item: any CodeEditSourceEditor.CodeSuggestionEntry,
        textView: TextViewController,
        cursorPosition: CursorPosition?
    ) {
        guard let item = item as? EditorCodeSuggestionEntry else { return }
        guard let view = textView.textView else { return }

        let replacementRange: NSRange
        if let textEditRange = item.replaceRange,
           let range = Self.nsRange(from: textEditRange, in: view.string) {
            replacementRange = range
        } else if let selectionRange = cursorPosition?.range, selectionRange.location != NSNotFound {
            if selectionRange.length == 0,
               let anchorOffset = requestAnchorOffset,
               anchorOffset <= selectionRange.location {
                replacementRange = NSRange(
                    location: anchorOffset,
                    length: selectionRange.location - anchorOffset
                )
            } else {
                replacementRange = selectionRange
            }
        } else if let anchorOffset = requestAnchorOffset {
            replacementRange = NSRange(location: anchorOffset, length: 0)
        } else {
            replacementRange = NSRange(location: view.string.utf16.count, length: 0)
        }

        if let selections = editorState?.applyMultiCursorReplacement(item.replacementText),
           selections.count > 1 {
            if let first = selections.first {
                view.selectionManager.setSelectedRange(NSRange(location: first.location, length: first.length))
            }
            return
        }

        view.replaceCharacters(in: replacementRange, with: item.replacementText)

        if let edits = item.additionalTextEdits, !edits.isEmpty {
            let sortedEdits = edits.sorted { lhs, rhs in
                let l = (lhs.range.start.line, lhs.range.start.character, lhs.range.end.character)
                let r = (rhs.range.start.line, rhs.range.start.character, rhs.range.end.character)
                return l > r
            }
            for edit in sortedEdits {
                guard let range = Self.nsRange(from: edit.range, in: view.string) else { continue }
                view.replaceCharacters(in: range, with: edit.newText)
            }
        }
    }

    func completionWindowDidSelect(item: any CodeEditSourceEditor.CodeSuggestionEntry) {}

    private static func utf16Offset(for position: CursorPosition.Position, in content: String) -> Int? {
        guard position.line > 0, position.column > 0 else { return nil }
        var currentLine = 1
        var currentColumn = 1
        var offset = 0
        for unit in content.utf16 {
            if currentLine == position.line && currentColumn == position.column {
                return offset
            }
            if unit == 0x0A {
                currentLine += 1
                currentColumn = 1
            } else {
                currentColumn += 1
            }
            offset += 1
        }
        if currentLine == position.line && currentColumn == position.column {
            return offset
        }
        return nil
    }

    private static func nsRange(from lspRange: LSPRange, in content: String) -> NSRange? {
        guard let start = utf16Offset(for: lspRange.start, in: content),
              let end = utf16Offset(for: lspRange.end, in: content),
              end >= start else {
            return nil
        }
        return NSRange(location: start, length: end - start)
    }

    private static func utf16Offset(for position: Position, in content: String) -> Int? {
        var line = 0
        var utf16Offset = 0
        var lineStartOffset = 0
        for scalar in content.unicodeScalars {
            if line == position.line {
                break
            }
            utf16Offset += scalar.utf16.count
            if scalar == "\n" {
                line += 1
                lineStartOffset = utf16Offset
            }
        }
        guard line == position.line else { return nil }
        return min(lineStartOffset + position.character, content.utf16.count)
    }
}

private struct EditorCodeSuggestionEntry: CodeEditSourceEditor.CodeSuggestionEntry {
    let item: CompletionItem

    var label: String { item.label }
    var detail: String? { item.detail }
    var documentation: String? {
        guard let documentation = item.documentation else { return nil }
        switch documentation {
        case .optionA(let text): return text
        case .optionB(let markup): return markup.value
        }
    }
    var pathComponents: [String]? { nil }
    var targetPosition: CursorPosition? { nil }
    var sourcePreview: String? { item.detail ?? item.label }
    var image: Image { Self.icon(for: item.kind) }
    var imageColor: SwiftUI.Color { Self.color(for: item.kind) }
    var deprecated: Bool { item.deprecated == true }

    var filterText: String? { item.filterText }
    var replacementText: String {
        switch item.textEdit {
        case .optionA(let edit):
            return edit.newText
        case .optionB(let edit):
            return edit.newText
        case nil:
            return item.insertText ?? item.label
        }
    }
    var replaceRange: LSPRange? {
        switch item.textEdit {
        case .optionA(let edit):
            return edit.range
        case .optionB(let edit):
            return edit.replace
        case nil:
            return nil
        }
    }
    var additionalTextEdits: [TextEdit]? { item.additionalTextEdits }

    static func icon(for kind: CompletionItemKind?) -> Image {
        switch kind {
        case .method, .function: return Image(systemName: "function")
        case .constructor: return Image(systemName: "hammer")
        case .field, .property: return Image(systemName: "square.and.pencil")
        case .variable: return Image(systemName: "textformat.abc")
        case .class: return Image(systemName: "square.3.layers.3d")
        case .interface: return Image(systemName: "square.on.square")
        case .module: return Image(systemName: "cube.box")
        case .enum: return Image(systemName: "list.bullet.rectangle")
        case .keyword: return Image(systemName: "text.badge.star")
        case .snippet: return Image(systemName: "curlybraces")
        case .file: return Image(systemName: "doc")
        case .folder: return Image(systemName: "folder")
        case .constant: return Image(systemName: "number")
        case .struct: return Image(systemName: "shippingbox")
        default: return Image(systemName: "text.bubble")
        }
    }

    static func color(for kind: CompletionItemKind?) -> SwiftUI.Color {
        switch kind {
        case .class, .struct, .interface: return SwiftUI.Color(NSColor.systemBlue)
        case .function, .method, .constructor: return SwiftUI.Color(NSColor.systemGreen)
        case .keyword: return SwiftUI.Color(NSColor.systemOrange)
        case .file, .folder, .module: return SwiftUI.Color(NSColor.systemPurple)
        default: return SwiftUI.Color(NSColor.secondaryLabelColor)
        }
    }
}
