import Foundation
@preconcurrency import EditorSource

/// 在 EditorService 模块内构造 `HighlightProviding`，避免插件跨模块实现时的 Swift 6 并发检查问题。
@MainActor
public final class DocumentHighlightHighlightAdapter: HighlightProviding {
    private let provider: any SuperEditorDocumentHighlightProvider

    public init(provider: any SuperEditorDocumentHighlightProvider) {
        self.provider = provider
    }

    public func setUp(textView: TextView, codeLanguage: CodeLanguage) {}

    public func queryHighlightsFor(
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

    public func applyEdit(
        textView: TextView,
        range: NSRange,
        delta: Int,
        completion: @escaping @MainActor (Result<IndexSet, Error>) -> Void
    ) {
        completion(.success(IndexSet()))
    }
}

/// 将静态高亮扫描逻辑包装为 `HighlightProviding`。
@MainActor
public final class StaticHighlightProviderAdapter: HighlightProviding {
    private let highlightsFor: @MainActor (String, NSRange) -> [HighlightRange]

    public init(highlightsFor: @escaping @MainActor (String, NSRange) -> [HighlightRange]) {
        self.highlightsFor = highlightsFor
    }

    public func setUp(textView: TextView, codeLanguage: CodeLanguage) {}

    public func applyEdit(
        textView: TextView,
        range: NSRange,
        delta: Int,
        completion: @escaping @MainActor (Result<IndexSet, Error>) -> Void
    ) {
        let documentLength = textView.string.utf16.count
        let clampedStart = min(max(0, range.location), documentLength)
        let clampedEnd = min(max(clampedStart, range.location + range.length + max(delta, 0)), documentLength)
        let invalidated = (textView.string as NSString).lineRange(
            for: NSRange(location: clampedStart, length: max(0, clampedEnd - clampedStart))
        )
        completion(.success(IndexSet(integersIn: invalidated.location..<(invalidated.location + invalidated.length))))
    }

    public func queryHighlightsFor(
        textView: TextView,
        range: NSRange,
        completion: @escaping @MainActor (Result<[HighlightRange], Error>) -> Void
    ) {
        completion(.success(highlightsFor(textView.string, range)))
    }
}
