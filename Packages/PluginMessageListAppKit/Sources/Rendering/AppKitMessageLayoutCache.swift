import Foundation

/// Bounded layout cache for the native message list.
///
/// Two tiers:
/// - **Document cache** keyed by content hash — parsing Markdown is never
///   repeated for unchanged source.
/// - **Height cache** keyed by `AppKitRowLayoutKey` (row identity + content
///   hash + width + scale + theme revision + verbosity).
///
/// Both tiers are LRU-bounded and expose hit/miss counters for diagnostics
/// (Task 15). Invalidation is targeted: by row, by content, or wholesale by
/// theme revision.
@MainActor
public final class AppKitMessageLayoutCache {
    public let documentLimit: Int
    public let heightLimit: Int

    public private(set) var documentHits = 0
    public private(set) var documentMisses = 0
    public private(set) var heightHits = 0
    public private(set) var heightMisses = 0

    private var documents: [String: AppKitMarkdownDocument] = [:]
    private var documentOrder: [String] = []
    private var heights: [AppKitRowLayoutKey: CGFloat] = [:]
    private var heightOrder: [AppKitRowLayoutKey] = []

    public init(documentLimit: Int = 500, heightLimit: Int = 2000) {
        self.documentLimit = documentLimit
        self.heightLimit = heightLimit
    }

    // MARK: - Documents

    /// Returns the cached document for `source` or parses and caches it.
    public func document(for source: String) -> AppKitMarkdownDocument {
        let hash = AppKitMarkdownParser.fnv1aHash(source)
        if let cached = documents[hash] {
            documentHits += 1
            touchDocument(hash)
            return cached
        }
        documentMisses += 1
        let parsed = AppKitMarkdownParser.parse(source)
        documents[hash] = parsed
        documentOrder.append(hash)
        evictDocumentsIfNeeded()
        return parsed
    }

    /// Returns the cached document only (nil on miss) without parsing.
    public func cachedDocument(for source: String) -> AppKitMarkdownDocument? {
        let hash = AppKitMarkdownParser.fnv1aHash(source)
        guard let cached = documents[hash] else { return nil }
        touchDocument(hash)
        return cached
    }

    // MARK: - Heights

    /// Returns the cached height for a key, or computes via `fallback` and
    /// caches it.
    public func height(
        for key: AppKitRowLayoutKey,
        fallback: () -> CGFloat
    ) -> CGFloat {
        if let cached = heights[key] {
            heightHits += 1
            touchHeight(key)
            return cached
        }
        heightMisses += 1
        let value = fallback()
        heights[key] = value
        heightOrder.append(key)
        evictHeightsIfNeeded()
        return value
    }

    /// Returns the cached height only (nil on miss).
    public func cachedHeight(for key: AppKitRowLayoutKey) -> CGFloat? {
        guard let cached = heights[key] else { return nil }
        touchHeight(key)
        return cached
    }

    // MARK: - Invalidation

    /// Removes every cached height for a row (content changed).
    public func invalidate(rowID: String) {
        let keys = heights.keys.filter { $0.rowID == rowID }
        for key in keys {
            heights.removeValue(forKey: key)
        }
        heightOrder.removeAll { keys.contains($0) }
    }

    /// Removes every height whose theme revision matches (theme change).
    public func invalidate(themeRevision: Int) {
        let keys = heights.keys.filter { $0.themeRevision == themeRevision }
        for key in keys {
            heights.removeValue(forKey: key)
        }
        heightOrder.removeAll { keys.contains($0) }
    }

    /// Removes cached documents and all heights (content model changed).
    public func invalidateAll() {
        documents.removeAll()
        documentOrder.removeAll()
        heights.removeAll()
        heightOrder.removeAll()
    }

    // MARK: - Private LRU bookkeeping

    private func touchDocument(_ hash: String) {
        documentOrder.removeAll { $0 == hash }
        documentOrder.append(hash)
    }

    private func touchHeight(_ key: AppKitRowLayoutKey) {
        heightOrder.removeAll { $0 == key }
        heightOrder.append(key)
    }

    private func evictDocumentsIfNeeded() {
        while documentOrder.count > documentLimit {
            let oldest = documentOrder.removeFirst()
            documents.removeValue(forKey: oldest)
        }
    }

    private func evictHeightsIfNeeded() {
        while heightOrder.count > heightLimit {
            let oldest = heightOrder.removeFirst()
            heights.removeValue(forKey: oldest)
        }
    }
}
