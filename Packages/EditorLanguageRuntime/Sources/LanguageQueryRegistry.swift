import Foundation
import SwiftTreeSitter

/// Loads and caches tree-sitter highlight queries from plugin-provided resource bundles.
public final class LanguageQueryRegistry: @unchecked Sendable {
    public static let shared = LanguageQueryRegistry()

    private let lock = NSLock()
    private var queries: [String: Query] = [:]

    private init() {}

    public func query(
        for grammarId: String,
        highlightURLs: [URL],
        parentHighlightURLs: [URL] = [],
        language: Language?
    ) -> Query? {
        lock.lock()
        if let cached = queries[grammarId] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let language else { return nil }

        var combinedSources = parentHighlightURLs.compactMap { try? String(contentsOf: $0) }
        combinedSources.append(contentsOf: highlightURLs.compactMap { try? String(contentsOf: $0) })
        guard !combinedSources.isEmpty else { return nil }

        let source = combinedSources.joined(separator: "\n")
        guard let query = try? Query(language: language, data: source.data(using: .utf8) ?? Data()) else {
            return nil
        }

        lock.lock()
        queries[grammarId] = query
        lock.unlock()
        return query
    }

    public func reset() {
        lock.lock()
        queries.removeAll()
        lock.unlock()
    }
}
