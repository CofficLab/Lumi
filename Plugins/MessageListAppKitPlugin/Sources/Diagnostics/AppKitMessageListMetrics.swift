import Foundation
import os.signpost

/// Centralized performance instrumentation for the AppKit message-list plugin.
///
/// Wraps `os_signpost` intervals around the hot paths (snapshot build/apply,
/// cell configure/reuse, Markdown parse, height measure, syntax highlight,
/// Mermaid render, scroll hitches) so Instruments can surface them without
/// production code carrying `#if DEBUG` noise.
///
/// Each metric family gets its own `OSSignposter` so a user can filter by
/// subsystem in Instruments.
enum AppKitMessageListMetrics {

    // MARK: - Subsystems

    private static let subsystem = "com.coffic.lumi.plugin.message-list-appkit"

    private static let snapshotLog = Logger(subsystem: subsystem, category: "snapshot")
    private static let cellLog = Logger(subsystem: subsystem, category: "cell")
    private static let markdownLog = Logger(subsystem: subsystem, category: "markdown")
    private static let layoutLog = Logger(subsystem: subsystem, category: "layout")
    private static let renderLog = Logger(subsystem: subsystem, category: "render")
    private static let scrollLog = Logger(subsystem: subsystem, category: "scroll")

    // MARK: - Snapshot

    static func snapshotBuildInterval(_ body: () -> Void) {
        let signposter = OSSignposter(logger:snapshotLog)
        let state = signposter.beginInterval("snapshot-build")
        body()
        signposter.endInterval("snapshot-build", state)
    }

    static func snapshotApplyInterval(_ body: () -> Void) {
        let signposter = OSSignposter(logger:snapshotLog)
        let state = signposter.beginInterval("snapshot-apply")
        body()
        signposter.endInterval("snapshot-apply", state)
    }

    // MARK: - Cell

    static func cellConfigureInterval(rowID: String, _ body: () -> Void) {
        let signposter = OSSignposter(logger:cellLog)
        let state = signposter.beginInterval("cell-configure", "\(rowID)")
        body()
        signposter.endInterval("cell-configure", state)
    }

    static func cellReuseInterval(_ body: () -> Void) {
        let signposter = OSSignposter(logger:cellLog)
        let state = signposter.beginInterval("cell-reuse")
        body()
        signposter.endInterval("cell-reuse", state)
    }

    // MARK: - Markdown

    static func markdownParseInterval(_ body: () -> Void) {
        let signposter = OSSignposter(logger:markdownLog)
        let state = signposter.beginInterval("markdown-parse")
        body()
        signposter.endInterval("markdown-parse", state)
    }

    // MARK: - Layout

    static func heightMeasureInterval(rowID: String, _ body: () -> Void) {
        let signposter = OSSignposter(logger:layoutLog)
        let state = signposter.beginInterval("height-measure", "\(rowID)")
        body()
        signposter.endInterval("height-measure", state)
    }

    // MARK: - Render (code/Mermaid)

    static func highlightInterval(language: String?, _ body: () -> Void) {
        let signposter = OSSignposter(logger:renderLog)
        let state = signposter.beginInterval("syntax-highlight", "\(language ?? "none")")
        body()
        signposter.endInterval("syntax-highlight", state)
    }

    static func mermaidRenderInterval(_ body: () -> Void) {
        let signposter = OSSignposter(logger:renderLog)
        let state = signposter.beginInterval("mermaid-render")
        body()
        signposter.endInterval("mermaid-render", state)
    }

    // MARK: - Scroll

    static func scrollHitchInterval(_ body: () -> Void) {
        let signposter = OSSignposter(logger:scrollLog)
        let state = signposter.beginInterval("scroll-hitch")
        body()
        signposter.endInterval("scroll-hitch", state)
    }

    // MARK: - Counters

    /// In-memory counters for diagnostic reporting (cache hits, parse counts, etc.).
    /// These are only meaningful during a test session or Instruments capture.
    @MainActor
    final class Counters: @unchecked Sendable {
        static let shared = Counters()

        private var values: [String: Int] = [:]
        private let lock = NSLock()

        func increment(_ key: String, by amount: Int = 1) {
            lock.lock()
            defer { lock.unlock() }
            values[key, default: 0] += amount
        }

        func get(_ key: String) -> Int {
            lock.lock()
            defer { lock.unlock() }
            return values[key, default: 0]
        }

        func reset() {
            lock.lock()
            defer { lock.unlock() }
            values.removeAll()
        }

        func snapshot() -> [String: Int] {
            lock.lock()
            defer { lock.unlock() }
            return values
        }
    }
}
