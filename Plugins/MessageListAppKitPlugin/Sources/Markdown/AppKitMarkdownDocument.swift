import Foundation
import MarkdownKitCore

/// Immutable, Sendable parsed Markdown document for one message body.
///
/// Documents are cached by `contentHash` so repeated scrolling never re-parses
/// unchanged source. All block content stays as pure value types — no `NSView`,
/// no `NSAttributedString`, no closures — so documents can be built off the
/// main actor.
public struct AppKitMarkdownDocument: Sendable, Equatable {
    public let source: String
    /// FNV-1a hash of the source; the cache key for documents.
    public let contentHash: String
    public let blocks: [MarkdownBlock]

    public init(source: String, contentHash: String, blocks: [MarkdownBlock]) {
        self.source = source
        self.contentHash = contentHash
        self.blocks = blocks
    }

    public var isEmpty: Bool {
        blocks.isEmpty
    }
}

/// Parses Markdown source into immutable documents.
public enum AppKitMarkdownParser {
    public static func parse(_ source: String) -> AppKitMarkdownDocument {
        let blocks = MarkdownParser.parse(source)
        return AppKitMarkdownDocument(
            source: source,
            contentHash: Self.fnv1aHash(source),
            blocks: blocks
        )
    }

    /// FNV-1a 64-bit hash rendered as lowercase hex — fast, dependency-free,
    /// stable across processes (no randomized hashing).
    public static func fnv1aHash(_ string: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}
