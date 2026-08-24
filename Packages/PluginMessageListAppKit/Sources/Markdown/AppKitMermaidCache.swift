import AppKit
import Foundation

/// LRU-bounded cache of rendered Mermaid images, keyed by source content hash.
/// Rendering is expensive; repeated scrolls must never re-render unchanged
/// diagrams.
@MainActor
public final class AppKitMermaidCache {
    public let limit: Int

    public private(set) var hits = 0
    public private(set) var misses = 0

    private var images: [String: NSImage] = [:]
    private var order: [String] = []
    /// Sources currently rendering; prevents duplicate concurrent work.
    private var inFlight: Set<String> = []

    public init(limit: Int = 40) {
        self.limit = limit
    }

    /// Returns the cached image for a source, or nil on miss.
    public func image(for source: String) -> NSImage? {
        let key = AppKitMarkdownParser.fnv1aHash(source)
        guard let image = images[key] else {
            misses += 1
            return nil
        }
        hits += 1
        touch(key)
        return image
    }

    /// Caches a rendered image.
    public func store(_ image: NSImage, for source: String) {
        let key = AppKitMarkdownParser.fnv1aHash(source)
        images[key] = image
        order.append(key)
        inFlight.remove(key)
        evictIfNeeded()
    }

    /// Marks a source as rendering; returns false when already in flight.
    @discardableResult
    public func beginRender(for source: String) -> Bool {
        let key = AppKitMarkdownParser.fnv1aHash(source)
        guard !inFlight.contains(key) else { return false }
        inFlight.insert(key)
        return true
    }

    /// Clears the in-flight marker (render failed or was cancelled).
    public func endRender(for source: String) {
        inFlight.remove(AppKitMarkdownParser.fnv1aHash(source))
    }

    public func invalidateAll() {
        images.removeAll()
        order.removeAll()
        inFlight.removeAll()
    }

    private func touch(_ key: String) {
        order.removeAll { $0 == key }
        order.append(key)
    }

    private func evictIfNeeded() {
        while order.count > limit {
            let oldest = order.removeFirst()
            images.removeValue(forKey: oldest)
        }
    }
}
