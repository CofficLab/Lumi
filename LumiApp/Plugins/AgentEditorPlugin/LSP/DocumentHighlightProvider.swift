@preconcurrency import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages
import LanguageServerProtocol
import Foundation

/// Document Highlight 提供者
/// 高亮当前光标所在位置的所有符号引用
@MainActor
final class DocumentHighlightProvider: ObservableObject {
    
    private let lspService = LSPService.shared
    
    /// 当前高亮的范围（NSRange 集合，用于编辑器高亮）
    @Published var highlightRanges: [NSRange] = []
    
    /// 请求文档高亮
    func requestHighlight(uri: String, line: Int, character: Int, content: String) async {
        let highlights = await lspService.requestDocumentHighlight(uri: uri, line: line, character: character)
        
        highlightRanges = highlights.compactMap { highlight -> NSRange? in
            let lspRange = highlight.range
            guard let nsRange = Self.nsRange(from: lspRange, in: content) else { return nil }
            return nsRange
        }
    }
    
    /// 清除高亮
    func clear() {
        highlightRanges.removeAll()
    }
    
    /// 是否有活跃高亮
    var isActive: Bool {
        !highlightRanges.isEmpty
    }
    
    // MARK: - Helpers
    
    private static func nsRange(from lspRange: LSPRange, in content: String) -> NSRange? {
        let startLine = Int(lspRange.start.line)
        let startChar = Int(lspRange.start.character)
        let endLine = Int(lspRange.end.line)
        let endChar = Int(lspRange.end.character)
        
        guard startLine >= 0, startChar >= 0, endLine >= 0, endChar >= 0 else { return nil }
        
        guard let start = utf16Offset(line: startLine, character: startChar, in: content),
              let end = utf16Offset(line: endLine, character: endChar, in: content),
              end >= start else {
            return nil
        }
        
        return NSRange(location: start, length: end - start)
    }
    
    private static func utf16Offset(line: Int, character: Int, in content: String) -> Int? {
        var currentLine = 0
        var offset = 0
        var lineStartOffset = 0
        
        for scalar in content.unicodeScalars {
            if currentLine == line {
                break
            }
            offset += scalar.utf16.count
            if scalar == "\n" {
                currentLine += 1
                lineStartOffset = offset
            }
        }
        
        guard currentLine == line else { return nil }
        return min(lineStartOffset + character, content.utf16.count)
    }
}

// MARK: - Highlight Providing

/// 基于 LSP 文档高亮的 HighlightProvider
@MainActor
final class DocumentHighlightHighlighter: HighlightProviding {
    
    private var provider: DocumentHighlightProvider
    
    init(provider: DocumentHighlightProvider) {
        self.provider = provider
    }
    
    func setUp(textView: TextView, codeLanguage: CodeLanguage) {
        // No-op
    }
    
    func queryHighlightsFor(
        textView: TextView,
        range: NSRange,
        completion: @escaping @MainActor (Result<[HighlightRange], Error>) -> Void
    ) {
        let ranges = provider.highlightRanges
        guard !ranges.isEmpty else {
            completion(.success([]))
            return
        }
        
        let highlights = ranges.compactMap { item -> HighlightRange? in
            let intersection = NSIntersectionRange(item, range)
            guard intersection.length > 0 else { return nil }
            return HighlightRange(range: intersection, capture: nil, modifiers: [])
        }
        
        completion(.success(highlights))
    }
    
    func applyEdit(
        textView: TextView,
        range: NSRange,
        delta: Int,
        completion: @escaping @MainActor (Result<IndexSet, Error>) -> Void
    ) {
        completion(.success(IndexSet()))
    }
}
