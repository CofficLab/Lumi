import Foundation
import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView
import LanguageServerProtocol

@MainActor
final class LSPCompletionDelegate: NSObject, CodeSuggestionDelegate {

    weak var lspCoordinator: LSPCoordinator?
    weak var editorState: EditorState?

    private var activeItems: [EditorCodeSuggestionEntry] = []
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

        let content = editorTextView.string
        let cursorOffset = Self.currentCursorOffset(in: editorTextView) ??
            Self.utf16Offset(for: cursorPosition.start, in: content) ??
            content.utf16.count
        let lspPosition = Self.lspPosition(fromUTF16Offset: cursorOffset, in: content)
        let line = lspPosition.line
        let character = lspPosition.character
        let completionItems = await coordinator.requestCompletion(line: line, character: character)
        var entries = completionItems.map(EditorCodeSuggestionEntry.init(item:))
        guard !entries.isEmpty else { return nil }

        let context = Self.completionContext(atOffset: cursorOffset, in: content)
        entries = Self.filterAndRank(
            entries: entries,
            prefix: context.prefix,
            typeContext: context.isTypeContext
        )
        requestAnchor = cursorPosition
        requestAnchorOffset = Self.utf16Offset(for: cursorPosition.start, in: content)
        activeItems = entries
        return (cursorPosition, entries.map { $0 })
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

        let cursorOffset = Self.currentCursorOffset(in: editorTextView) ??
            Self.utf16Offset(for: cursorPosition.start, in: editorTextView.string) ??
            editorTextView.string.utf16.count
        let context = Self.completionContext(atOffset: cursorOffset, in: editorTextView.string)
        let filtered = Self.filterAndRank(
            entries: activeItems,
            prefix: context.prefix,
            typeContext: context.isTypeContext
        )
        return filtered.isEmpty ? nil : filtered.map { $0 }
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

    private struct CompletionContext {
        let prefix: String
        let isTypeContext: Bool
    }

    private static func completionContext(atOffset rawOffset: Int, in content: String) -> CompletionContext {
        let cursorOffset = min(max(rawOffset, 0), content.utf16.count)
        let ns = content as NSString
        var tokenStart = cursorOffset
        while tokenStart > 0 {
            let unit = ns.character(at: tokenStart - 1)
            guard isIdentifierScalar(unit) else { break }
            tokenStart -= 1
        }
        let prefix = ns.substring(with: NSRange(location: tokenStart, length: cursorOffset - tokenStart))
        var check = tokenStart
        while check > 0 {
            let unit = ns.character(at: check - 1)
            if let scalar = UnicodeScalar(unit),
               CharacterSet.whitespacesAndNewlines.contains(scalar) {
                check -= 1
                continue
            }
            return CompletionContext(prefix: prefix, isTypeContext: unit == 0x3A) // ":"
        }
        return CompletionContext(prefix: prefix, isTypeContext: false)
    }

    private static func currentCursorOffset(in textView: NSTextView) -> Int? {
        let selection = textView.selectedRange()
        guard selection.location != NSNotFound else { return nil }
        return min(selection.location, textView.string.utf16.count)
    }

    private static func lspPosition(fromUTF16Offset rawOffset: Int, in content: String) -> Position {
        let offset = min(max(rawOffset, 0), content.utf16.count)
        let ns = content as NSString
        var line = 0
        var character = 0
        var index = 0

        while index < offset {
            let unit = ns.character(at: index)
            if unit == 0x0A {
                line += 1
                character = 0
            } else {
                character += 1
            }
            index += 1
        }

        return Position(line: line, character: character)
    }

    private static func isIdentifierScalar(_ scalar: unichar) -> Bool {
        if scalar == 0x5F { return true } // "_"
        guard let u = UnicodeScalar(scalar) else { return false }
        return CharacterSet.alphanumerics.contains(u)
    }

    private static func filterAndRank(
        entries: [EditorCodeSuggestionEntry],
        prefix: String,
        typeContext: Bool
    ) -> [EditorCodeSuggestionEntry] {
        let typeFiltered: [EditorCodeSuggestionEntry]
        if typeContext {
            let onlyTypeLike = entries.filter(isTypeLike)
            typeFiltered = onlyTypeLike.isEmpty ? entries : onlyTypeLike
        } else {
            typeFiltered = entries
        }

        guard !prefix.isEmpty else {
            return rank(entries: typeFiltered, prefix: prefix, typeContext: typeContext)
        }
        let lowerPrefix = prefix.lowercased()
        let filtered = typeFiltered.filter { entry in
            entry.label.lowercased().hasPrefix(lowerPrefix) ||
                entry.filterText?.lowercased().hasPrefix(lowerPrefix) == true
        }
        guard !filtered.isEmpty else { return [] }
        return rank(entries: filtered, prefix: prefix, typeContext: typeContext)
    }

    private static func rank(
        entries: [EditorCodeSuggestionEntry],
        prefix: String,
        typeContext: Bool
    ) -> [EditorCodeSuggestionEntry] {
        let preferredTypes: Set<String> = [
            "Int", "Int8", "Int16", "Int32", "Int64",
            "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
            "Float", "Double", "Bool", "String"
        ]
        let lowerPrefix = prefix.lowercased()

        return entries.sorted { lhs, rhs in
            let lPinned = pinnedTypeOrder(for: lhs, prefix: lowerPrefix, typeContext: typeContext)
            let rPinned = pinnedTypeOrder(for: rhs, prefix: lowerPrefix, typeContext: typeContext)
            if lPinned != rPinned {
                switch (lPinned, rPinned) {
                case let (.some(l), .some(r)):
                    return l < r
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    break
                }
            }

            let l = score(
                for: lhs,
                prefix: lowerPrefix,
                typeContext: typeContext,
                preferredTypes: preferredTypes
            )
            let r = score(
                for: rhs,
                prefix: lowerPrefix,
                typeContext: typeContext,
                preferredTypes: preferredTypes
            )
            if l != r { return l > r }
            if lhs.label.count != rhs.label.count { return lhs.label.count < rhs.label.count }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
    }

    private static func score(
        for entry: EditorCodeSuggestionEntry,
        prefix: String,
        typeContext: Bool,
        preferredTypes: Set<String>
    ) -> Int {
        var result = 0
        let label = entry.label
        let lowerLabel = label.lowercased()
        let lowerFilter = entry.filterText?.lowercased()

        if !prefix.isEmpty {
            if lowerLabel == prefix { result += 5_000 }
            if lowerLabel.hasPrefix(prefix) { result += 3_000 }
            if lowerFilter?.hasPrefix(prefix) == true { result += 2_500 }
        }

        if entry.item.preselect == true { result += 250 }
        if entry.deprecated { result -= 800 }

        if typeContext {
            if preferredTypes.contains(label) { result += 4_000 }
            if isLikelyLiteral(label) { result -= 2_200 }
            switch entry.item.kind {
            case .class, .struct, .enum, .interface, .typeParameter:
                result += 1_400
            case .keyword:
                result -= 1_800
            default:
                break
            }
            if isLowercaseKeywordLike(label) { result -= 1_200 }
        }

        switch entry.item.kind {
        case .keyword: result += 180
        case .class, .struct, .enum, .interface: result += 150
        case .typeParameter: result += 140
        case .module, .file, .folder: result -= 60
        default: break
        }

        return result
    }

    private static func pinnedTypeOrder(
        for entry: EditorCodeSuggestionEntry,
        prefix: String,
        typeContext: Bool
    ) -> Int? {
        guard typeContext else { return nil }

        let orderedTypes: [String] = [
            "Int", "Int8", "Int16", "Int32", "Int64",
            "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
            "Double", "Float", "CGFloat", "Bool", "String",
            "Character", "Any", "AnyObject"
        ]
        guard let index = orderedTypes.firstIndex(of: entry.label) else { return nil }
        guard prefix.isEmpty || entry.label.lowercased().hasPrefix(prefix) else { return nil }
        return index
    }

    private static func isTypeLike(_ entry: EditorCodeSuggestionEntry) -> Bool {
        let label = entry.label
        if label.isEmpty { return false }
        if isLikelyLiteral(label) { return false }
        if isLowercaseKeywordLike(label) { return false }

        switch entry.item.kind {
        case .class, .struct, .enum, .interface, .typeParameter, .module:
            return true
        case .keyword:
            return label.first?.isUppercase == true
        default:
            break
        }

        if label.first?.isUppercase == true {
            return true
        }

        if let detail = entry.detail?.lowercased() {
            if detail.contains("typealias") ||
                detail.contains("protocol") ||
                detail.contains("struct") ||
                detail.contains("class") ||
                detail.contains("enum") ||
                detail.contains("actor") {
                return true
            }
        }

        return false
    }

    private static func isLowercaseKeywordLike(_ label: String) -> Bool {
        let keywords: Set<String> = [
            "if", "else", "switch", "case", "default", "for", "while", "repeat",
            "do", "try", "catch", "throw", "return", "break", "continue",
            "let", "var", "func", "class", "struct", "enum", "protocol",
            "extension", "import", "nil", "true", "false", "guard", "defer",
            "where", "as", "is", "in"
        ]
        return keywords.contains(label.lowercased())
    }

    private static func isLikelyLiteral(_ label: String) -> Bool {
        guard !label.isEmpty else { return false }
        if label.first?.isNumber == true { return true }
        if label.hasPrefix("\"") || label.hasPrefix("'") { return true }
        return false
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
