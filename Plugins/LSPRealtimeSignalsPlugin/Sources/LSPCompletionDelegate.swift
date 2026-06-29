import Foundation
import EditorService
import SuperLogKit
import SwiftUI
import LanguageServerProtocol
import os

private protocol ApplicableCompletionEntry: CodeSuggestionEntry {
    var replacementText: String { get }
    var replaceRange: LSPRange? { get }
    var additionalTextEdits: [TextEdit]? { get }
    var snippetText: String? { get }
}

@MainActor
public final class LSPCompletionDelegate: NSObject, CodeSuggestionDelegate, SuperLog {
    public nonisolated static let emoji = "💡"
    public nonisolated static let verbose = true
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.lsp.realtime.completion")

    weak var lspClient: (any SuperEditorLSPClient)?
    weak var editorExtensionRegistry: EditorExtensionRegistry?
    weak var editorState: EditorState?

    private var sessionContext: (any LSPCompletionSessionContext)? {
        editorState
    }

    private var activeItems: [EditorCodeSuggestionEntry] = []
    private var requestAnchor: CursorPosition?
    private var requestAnchorOffset: Int?
    private var activeRequestID: Int?
    private var requestSequence = 0
    private var lastMoveDebugSignature: String?
    private var activePluginItems: [EditorPluginSuggestionEntry] = []
    private var activeFallbackTypeItems: [LocalTypeSuggestionEntry] = []
    private let requestGeneration = RequestGeneration()

    public func configure(
        lspClient: (any SuperEditorLSPClient)?,
        editorExtensionRegistry: EditorExtensionRegistry?,
        editorState: EditorState?
    ) {
        self.lspClient = lspClient
        self.editorExtensionRegistry = editorExtensionRegistry
        self.editorState = editorState
    }

    public func completionTriggerCharacters() -> Set<String> {
        let characters = lspClient?.completionTriggerCharacters() ?? []
        return characters.isEmpty ? ["."] : characters
    }

    public func completionSuggestionsRequested(
        textView: TextViewController,
        cursorPosition: CursorPosition
    ) async -> (windowPosition: CursorPosition, items: [any CodeSuggestionEntry])? {
        guard let lspClient else { return nil }
        guard let editorTextView = textView.textView else { return nil }

        let content = editorTextView.string
        let cursorOffset = Self.currentCursorOffset(in: editorTextView) ??
            Self.utf16Offset(for: cursorPosition.start, in: content) ??
            content.utf16.count

        return await resolveCompletion(
            content: content,
            cursorOffset: cursorOffset,
            cursorPosition: cursorPosition,
            lspClient: lspClient,
            registry: editorExtensionRegistry,
            session: sessionContext
        )
    }

    /// Test seam for completion resolution without AppKit text view wiring.
    func resolveCompletion(
        content: String,
        cursorOffset: Int,
        cursorPosition: CursorPosition,
        lspClient: any SuperEditorLSPClient,
        registry: EditorExtensionRegistry?,
        session: (any LSPCompletionSessionContext)?
    ) async -> (windowPosition: CursorPosition, items: [any CodeSuggestionEntry])? {
        let lspPosition = Self.lspPosition(fromUTF16Offset: cursorOffset, in: content)
        let line = lspPosition.line
        let character = lspPosition.character
        let context = LSPCompletionContextAnalyzer.analyze(atOffset: cursorOffset, in: content)
        let preflightError = session?.semanticCapability?.preflightError(
            uri: session?.currentFileURL?.absoluteString,
            operation: "代码补全",
            symbolName: nil,
            strength: .soft
        )
        if !LSPCompletionPreflightGate.shouldQueryLSP(preflightError: preflightError, context: context) {
            if let registry {
                let extensionContext = EditorCompletionContext(
                    languageId: session?.languageId ?? "swift",
                    line: line,
                    character: character,
                    prefix: context.prefix,
                    isTypeContext: context.isTypeContext
                )
                let extensionSuggestions = await registry.completionSuggestions(for: extensionContext)
                let extensionEntries = extensionSuggestions.map(EditorPluginSuggestionEntry.init)
                if !extensionEntries.isEmpty {
                    requestAnchor = cursorPosition
                    requestAnchorOffset = Self.utf16Offset(for: cursorPosition.start, in: content)
                    activeItems.removeAll()
                    activePluginItems = extensionEntries
                    activeFallbackTypeItems.removeAll()
                    return (cursorPosition, extensionEntries.map { $0 })
                }
            }
            return nil
        }

        requestSequence += 1
        let requestID = requestSequence
        let requestGen = requestGeneration.next()
        activeRequestID = requestID
        lastMoveDebugSignature = nil
        if Self.verbose {
            if Self.verbose {
                            Self.logger.debug("\(Self.t)补全请求[\(requestID)] 发起: 事件行列=\(cursorPosition.start.line):\(cursorPosition.start.column), 实时offset=\(cursorOffset), LSP行列=\(line):\(character), 前缀='\(context.prefix)', 类型上下文=\(context.isTypeContext), 成员访问=\(context.isMemberAccessContext)")
            }
        }

        let completionItems = await lspClient.requestCompletion(line: line, character: character)
        guard requestGeneration.isCurrent(requestGen) else { return nil }
        var entries = completionItems.map(EditorCodeSuggestionEntry.init(item:))
        let extensionContext = EditorCompletionContext(
            languageId: session?.languageId ?? "swift",
            line: line,
            character: character,
            prefix: context.prefix,
            isTypeContext: context.isTypeContext
        )
        let extensionSuggestions = await registry?.completionSuggestions(for: extensionContext) ?? []
        guard requestGeneration.isCurrent(requestGen) else { return nil }
        let extensionEntries = extensionSuggestions.map(EditorPluginSuggestionEntry.init)
        if Self.verbose {
            if Self.verbose {
                            Self.logger.debug("\(Self.t)补全请求[\(requestID)] LSP返回: \(entries.count) 项，扩展=\(extensionEntries.count) 项")
            }
        }
        guard !entries.isEmpty else {
            if !extensionEntries.isEmpty {
                requestAnchor = cursorPosition
                requestAnchorOffset = Self.utf16Offset(for: cursorPosition.start, in: content)
                activeItems.removeAll()
                activePluginItems = extensionEntries
                activeFallbackTypeItems.removeAll()
                let combined = Self.combineSuggestions(
                    lsp: [],
                    plugin: extensionEntries,
                    prioritizePlugin: context.isTypeContext
                )
                return (cursorPosition, combined.map { $0 })
            }
            if context.isTypeContext {
                let fallback = Self.fallbackTypeEntries(prefix: context.prefix)
                if !fallback.isEmpty {
                    if Self.verbose {
                        let preview = fallback.prefix(5).map(\.label).joined(separator: ", ")
                        if Self.verbose {
                                                    Self.logger.debug("\(Self.t)补全请求[\(requestID)] LSP空返回，启用类型兜底: \(fallback.count) 项，Top=\(preview)")
                        }
                    }
                    requestAnchor = cursorPosition
                    requestAnchorOffset = Self.utf16Offset(for: cursorPosition.start, in: content)
                    activeItems.removeAll()
                    activeFallbackTypeItems = fallback
                    return (cursorPosition, fallback.map { $0 })
                }
            }
            activeItems.removeAll()
            activePluginItems.removeAll()
            activeFallbackTypeItems.removeAll()
            requestAnchor = nil
            requestAnchorOffset = nil
            if Self.verbose {
                if Self.verbose {
                                    Self.logger.debug("\(Self.t)补全请求[\(requestID)] 无返回项，结束")
                }
            }
            return nil
        }

        let beforeFilterCount = entries.count
        entries = Self.filterAndRank(
            entries: entries,
            prefix: context.prefix,
            typeContext: context.isTypeContext
        )
        if Self.verbose {
            let preview = entries.prefix(5).map(\.label).joined(separator: ", ")
            if Self.verbose {
                            Self.logger.debug("\(Self.t)补全请求[\(requestID)] 本地过滤排序: \(beforeFilterCount) -> \(entries.count)，Top=\(preview)")
            }
        }
        requestAnchor = cursorPosition
        requestAnchorOffset = Self.utf16Offset(for: cursorPosition.start, in: content)
        activeItems = entries
        activePluginItems = extensionEntries
        activeFallbackTypeItems.removeAll()
        if activeItems.isEmpty && activePluginItems.isEmpty {
            if context.isTypeContext {
                let fallback = Self.fallbackTypeEntries(prefix: context.prefix)
                if !fallback.isEmpty {
                    if Self.verbose {
                        let preview = fallback.prefix(5).map(\.label).joined(separator: ", ")
                        if Self.verbose {
                                                    Self.logger.debug("\(Self.t)补全请求[\(requestID)] 过滤为空，启用类型兜底: \(fallback.count) 项，Top=\(preview)")
                        }
                    }
                    activeFallbackTypeItems = fallback
                    return (cursorPosition, fallback.map { $0 })
                }
            }
            if Self.verbose {
                if Self.verbose {
                                    Self.logger.debug("\(Self.t)补全请求[\(requestID)] 过滤后为空，不展示补全窗")
                }
            }
            return nil
        }
        let combined = Self.combineSuggestions(
            lsp: activeItems,
            plugin: activePluginItems,
            prioritizePlugin: context.isTypeContext
        )
        return (cursorPosition, combined.map { $0 })
    }

    public func completionOnCursorMove(
        textView: TextViewController,
        cursorPosition: CursorPosition
    ) -> [any CodeSuggestionEntry]? {
        guard let anchor = requestAnchor else { return nil }
        guard let editorTextView = textView.textView else { return nil }
        if cursorPosition.start.line != anchor.start.line ||
            cursorPosition.start.column < anchor.start.column {
            return nil
        }

        let cursorOffset = Self.currentCursorOffset(in: editorTextView) ??
            Self.utf16Offset(for: cursorPosition.start, in: editorTextView.string) ??
            editorTextView.string.utf16.count
        let context = LSPCompletionContextAnalyzer.analyze(atOffset: cursorOffset, in: editorTextView.string)
        if !activeFallbackTypeItems.isEmpty {
            let filtered = Self.fallbackTypeEntries(prefix: context.prefix)
            if Self.verbose {
                    let requestID = activeRequestID ?? -1
                    let signature = "fallback|\(requestID)|\(context.prefix)|\(filtered.count)"
                    if signature != lastMoveDebugSignature {
                        let preview = filtered.prefix(5).map(\.label).joined(separator: ", ")
                        if Self.verbose {
                                                    Self.logger.debug("\(Self.t)补全重筛[\(requestID)](兜底) 前缀='\(context.prefix)' \(self.activeFallbackTypeItems.count)->\(filtered.count)，Top=\(preview)")
                        }
                        lastMoveDebugSignature = signature
                    }
                }
            activeFallbackTypeItems = filtered
            return filtered.isEmpty ? nil : filtered.map { $0 }
        }
        guard !activeItems.isEmpty || !activePluginItems.isEmpty else { return nil }
        let sourceCount = activeItems.count
        let filtered = Self.filterAndRank(
            entries: activeItems,
            prefix: context.prefix,
            typeContext: context.isTypeContext
        )
        let pluginFiltered = Self.filterPluginEntries(entries: activePluginItems, prefix: context.prefix)
        if Self.verbose {
            let requestID = activeRequestID ?? -1
            let signature = "\(requestID)|\(context.prefix)|\(sourceCount)|\(filtered.count)|\(pluginFiltered.count)|\(context.isTypeContext)"
            if signature != lastMoveDebugSignature {
                let combinedPreview = Self.combineSuggestions(
                    lsp: filtered,
                    plugin: pluginFiltered,
                    prioritizePlugin: context.isTypeContext
                ).prefix(5).map(\.label).joined(separator: ", ")
                if Self.verbose {
                                    Self.logger.debug("\(Self.t)补全重筛[\(requestID)] 前缀='\(context.prefix)' 类型上下文=\(context.isTypeContext) LSP \(sourceCount)->\(filtered.count), 扩展=\(pluginFiltered.count)，Top=\(combinedPreview)")
                }
                lastMoveDebugSignature = signature
            }
        }
        let combined = Self.combineSuggestions(
            lsp: filtered,
            plugin: pluginFiltered,
            prioritizePlugin: context.isTypeContext
        )
        return combined.isEmpty ? nil : combined.map { $0 }
    }

    public func completionWindowDidClose() {
        requestGeneration.invalidate()
        if Self.verbose {
            let requestID = activeRequestID ?? -1
            if Self.verbose {
                            Self.logger.debug("\(Self.t)补全窗口关闭[\(requestID)]")
            }
        }
        activeItems.removeAll()
        activePluginItems.removeAll()
        activeFallbackTypeItems.removeAll()
        requestAnchor = nil
        requestAnchorOffset = nil
        activeRequestID = nil
        lastMoveDebugSignature = nil
    }

    public func completionWindowApplyCompletion(
        item: any CodeSuggestionEntry,
        textView: TextViewController,
        cursorPosition: CursorPosition?
    ) {
        guard let item = item as? any ApplicableCompletionEntry else { return }
        guard let view = textView.textView else { return }
        if Self.verbose {
            let requestID = activeRequestID ?? -1
            if Self.verbose {
                            Self.logger.debug("\(Self.t)应用补全[\(requestID)] label='\(item.label)' replacement='\(item.replacementText)'")
            }
        }

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

        if let snippetText = item.snippetText,
           let state = editorState,
           state.applySnippetCompletionEdit(
                replacementRange: replacementRange,
                snippetText: snippetText,
                additionalTextEdits: item.additionalTextEdits
           ) {
            if let first = state.currentSelectionsAsNSRanges().first {
                view.selectionManager.setSelectedRange(first)
            }
            return
        }

        if let selections = editorState?.applyMultiCursorReplacement(item.replacementText),
           selections.count > 1 {
            if let first = selections.first {
                view.selectionManager.setSelectedRange(NSRange(location: first.location, length: first.length))
            }
            return
        }

        if let state = editorState,
           state.applyCompletionEdit(
                replacementRange: replacementRange,
                replacementText: item.replacementText,
                additionalTextEdits: item.additionalTextEdits
           ) {
            if let first = state.currentSelectionsAsNSRanges().first {
                view.selectionManager.setSelectedRange(first)
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

    public func completionWindowDidSelect(item: any CodeSuggestionEntry) {}

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

    private static func currentCursorOffset(in textView: TextView) -> Int? {
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
            matchesPrefix(entry: entry, lowerPrefix: lowerPrefix)
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
        let canonical = canonicalCompletionLabel(from: label).lowercased()

        if !prefix.isEmpty {
            if lowerLabel == prefix { result += 5_000 }
            if canonical == prefix { result += 4_500 }
            if lowerLabel.hasPrefix(prefix) { result += 3_000 }
            if canonical.hasPrefix(prefix) { result += 2_800 }
            if lowerFilter?.hasPrefix(prefix) == true { result += 2_500 }
        }

        if entry.item.preselect == true { result += 250 }
        if entry.deprecated { result -= 800 }

        if typeContext {
            let canonicalLabel = canonicalCompletionLabel(from: label)
            if preferredTypes.contains(canonicalLabel) { result += 4_000 }
            if isCTypeAlias(canonicalLabel) { result -= 3_200 }
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

    private static func matchesPrefix(entry: EditorCodeSuggestionEntry, lowerPrefix: String) -> Bool {
        if entry.label.lowercased().hasPrefix(lowerPrefix) { return true }
        if entry.filterText?.lowercased().hasPrefix(lowerPrefix) == true { return true }

        let canonical = canonicalCompletionLabel(from: entry.label).lowercased()
        if canonical.hasPrefix(lowerPrefix) { return true }

        if let detail = entry.detail?.lowercased(), detail.hasPrefix(lowerPrefix) {
            return true
        }

        let tokens = tokenizeCompletionLabel(entry.label)
        return tokens.contains { $0.lowercased().hasPrefix(lowerPrefix) }
    }

    private static func canonicalCompletionLabel(from label: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let droppedNumericPrefix = trimmed.replacingOccurrences(
            of: #"^\d+\s+"#,
            with: "",
            options: .regularExpression
        )
        return droppedNumericPrefix
    }

    private static func tokenizeCompletionLabel(_ label: String) -> [String] {
        let canonical = canonicalCompletionLabel(from: label)
        return canonical.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
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
        guard prefix.isEmpty || matchesPrefix(entry: entry, lowerPrefix: prefix) else { return nil }

        let canonicalLabel = canonicalCompletionLabel(from: entry.label)
        if let index = orderedTypes.firstIndex(of: canonicalLabel) {
            return index
        }
        if let bridgedSwiftType = bridgedSwiftType(forCTypeAlias: canonicalLabel),
           let index = orderedTypes.firstIndex(of: bridgedSwiftType) {
            return orderedTypes.count + index
        }
        return nil
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

    private static func isCTypeAlias(_ typeName: String) -> Bool {
        bridgedSwiftType(forCTypeAlias: typeName) != nil
    }

    private static func bridgedSwiftType(forCTypeAlias typeName: String) -> String? {
        let map: [String: String] = [
            "CChar": "Int8",
            "CSignedChar": "Int8",
            "CUnsignedChar": "UInt8",
            "CShort": "Int16",
            "CUnsignedShort": "UInt16",
            "CInt": "Int32",
            "CUnsignedInt": "UInt32",
            "CLong": "Int",
            "CUnsignedLong": "UInt",
            "CLongLong": "Int64",
            "CUnsignedLongLong": "UInt64"
        ]
        return map[typeName]
    }

    private static func fallbackTypeEntries(prefix: String) -> [LocalTypeSuggestionEntry] {
        let orderedTypes: [String] = [
            "Int", "Int8", "Int16", "Int32", "Int64",
            "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
            "Double", "Float", "CGFloat", "Bool", "String",
            "Character", "Any", "AnyObject"
        ]
        let lowerPrefix = prefix.lowercased()
        let filtered = orderedTypes.filter { candidate in
            lowerPrefix.isEmpty || candidate.lowercased().hasPrefix(lowerPrefix)
        }
        return filtered.map { LocalTypeSuggestionEntry(label: $0) }
    }

    private static func filterPluginEntries(
        entries: [EditorPluginSuggestionEntry],
        prefix: String
    ) -> [EditorPluginSuggestionEntry] {
        guard !prefix.isEmpty else {
            return entries.sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
        }
        let lowerPrefix = prefix.lowercased()
        return entries.filter { $0.label.lowercased().hasPrefix(lowerPrefix) }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
    }

    private static func combineSuggestions(
        lsp: [EditorCodeSuggestionEntry],
        plugin: [EditorPluginSuggestionEntry],
        prioritizePlugin: Bool
    ) -> [any ApplicableCompletionEntry] {
        var seen: Set<String> = []
        var merged: [any ApplicableCompletionEntry] = []

        let appendItem: (any ApplicableCompletionEntry) -> Void = { item in
            let key = item.label.lowercased()
            guard !seen.contains(key) else { return }
            seen.insert(key)
            merged.append(item)
        }

        if prioritizePlugin {
            plugin.forEach(appendItem)
            lsp.forEach(appendItem)
        } else {
            lsp.forEach(appendItem)
            plugin.forEach(appendItem)
        }
        return merged
    }
}

private struct EditorCodeSuggestionEntry: ApplicableCompletionEntry {
    public let item: CompletionItem

    public var label: String { item.label }
    public var detail: String? { item.detail }
    public var documentation: String? {
        guard let documentation = item.documentation else { return nil }
        switch documentation {
        case .optionA(let text): return text
        case .optionB(let markup): return markup.value
        }
    }
    public var pathComponents: [String]? { nil }
    public var targetPosition: CursorPosition? { nil }
    public var sourcePreview: String? { item.detail ?? item.label }
    public var image: Image { Self.icon(for: item.kind) }
    public var imageColor: SwiftUI.Color { Self.color(for: item.kind) }
    public var deprecated: Bool { item.deprecated == true }

    public var filterText: String? { item.filterText }
    public var replacementText: String {
        switch item.textEdit {
        case .optionA(let edit):
            return edit.newText
        case .optionB(let edit):
            return edit.newText
        case nil:
            return item.insertText ?? item.label
        }
    }
    public var replaceRange: LSPRange? {
        switch item.textEdit {
        case .optionA(let edit):
            return edit.range
        case .optionB(let edit):
            return edit.replace
        case nil:
            return nil
        }
    }
    public var additionalTextEdits: [TextEdit]? { item.additionalTextEdits }
    public var snippetText: String? {
        item.insertTextFormat == .snippet ? replacementText : nil
    }

    public static func icon(for kind: CompletionItemKind?) -> Image {
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

    public static func color(for kind: CompletionItemKind?) -> SwiftUI.Color {
        switch kind {
        case .class, .struct, .interface: return SwiftUI.Color(NSColor.systemBlue)
        case .function, .method, .constructor: return SwiftUI.Color(NSColor.systemGreen)
        case .keyword: return SwiftUI.Color(NSColor.systemOrange)
        case .file, .folder, .module: return SwiftUI.Color(NSColor.systemPurple)
        default: return SwiftUI.Color(NSColor.secondaryLabelColor)
        }
    }
}

private struct EditorPluginSuggestionEntry: ApplicableCompletionEntry {
    public let suggestion: EditorCompletionSuggestion

    public init(_ suggestion: EditorCompletionSuggestion) {
        self.suggestion = suggestion
    }

    public var label: String { suggestion.label }
    public var detail: String? { suggestion.detail }
    public var documentation: String? { nil }
    public var pathComponents: [String]? { nil }
    public var targetPosition: CursorPosition? { nil }
    public var sourcePreview: String? { detail ?? label }
    public var image: Image { Image(systemName: "puzzlepiece.extension") }
    public var imageColor: SwiftUI.Color { SwiftUI.Color(NSColor.systemIndigo) }
    public var deprecated: Bool { false }
    public var replacementText: String { suggestion.insertText }
    public var replaceRange: LSPRange? { nil }
    public var additionalTextEdits: [TextEdit]? { nil }
    public var snippetText: String? { nil }
    public var priority: Int { suggestion.priority }
}

private struct LocalTypeSuggestionEntry: ApplicableCompletionEntry {
    public let label: String

    public var detail: String? { "Swift Type" }
    public var documentation: String? { nil }
    public var pathComponents: [String]? { nil }
    public var targetPosition: CursorPosition? { nil }
    public var sourcePreview: String? { detail }
    public var image: Image { Image(systemName: "text.bubble") }
    public var imageColor: SwiftUI.Color { SwiftUI.Color(NSColor.secondaryLabelColor) }
    public var deprecated: Bool { false }
    public var replacementText: String { label }
    public var replaceRange: LSPRange? { nil }
    public var additionalTextEdits: [TextEdit]? { nil }
    public var snippetText: String? { nil }
}
