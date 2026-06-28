import Foundation
import os
import SuperLogKit

public enum EditorPerfEvent: String, Sendable, CaseIterable {
    case fileOpen = "file.open"
    case fileOpenRead = "file.open.read"
    case fileOpenDetect = "file.open.detect"
    case fileOpenLSP = "file.open.lsp"
    case fileOpenRender = "file.open.render"
    case fileSave = "file.save"
    case fileSavePipeline = "file.save.pipeline"

    case editTransaction = "edit.transaction"
    case editFormat = "edit.format"
    case editRename = "edit.rename"
    case editCodeAction = "edit.codeAction"
    case editLineEdit = "edit.lineEdit"

    case lspCompletion = "lsp.completion"
    case lspHover = "lsp.hover"
    case lspDiagnostics = "lsp.diagnostics"
    case lspInlayHints = "lsp.inlayHints"
    case lspReferences = "lsp.references"
    case lspSignatureHelp = "lsp.signatureHelp"

    case renderViewport = "render.viewport"
    case renderBracketMatch = "render.bracket"
    case renderSyntaxHighlight = "render.syntax"
    case renderFindMatches = "render.find"

    case sessionSwitch = "session.switch"
    case sessionRestore = "session.restore"
}

public struct EditorPerfResult: Sendable {
    public let event: EditorPerfEvent
    public let duration: TimeInterval
    public let timestamp: Date
    public let metadata: [String: String]

    public var isSlow: Bool {
        duration > Self.slowThreshold(for: event)
    }

    public init(event: EditorPerfEvent, duration: TimeInterval, timestamp: Date, metadata: [String: String]) {
        self.event = event
        self.duration = duration
        self.timestamp = timestamp
        self.metadata = metadata
    }

    public static func slowThreshold(for event: EditorPerfEvent) -> TimeInterval {
        switch event {
        case .fileOpen: return 500
        case .fileOpenRead: return 200
        case .fileOpenDetect: return 50
        case .fileOpenLSP: return 300
        case .fileOpenRender: return 200
        case .fileSave: return 300
        case .fileSavePipeline: return 200
        case .editTransaction: return 16
        case .editFormat: return 500
        case .editRename: return 500
        case .editCodeAction: return 200
        case .editLineEdit: return 16
        case .lspCompletion: return 200
        case .lspHover: return 300
        case .lspDiagnostics: return 500
        case .lspInlayHints: return 500
        case .lspReferences: return 500
        case .lspSignatureHelp: return 300
        case .renderViewport: return 16
        case .renderBracketMatch: return 5
        case .renderSyntaxHighlight: return 50
        case .renderFindMatches: return 50
        case .sessionSwitch: return 100
        case .sessionRestore: return 100
        }
    }
}

public struct EditorPerfSummary: Sendable {
    public let event: EditorPerfEvent
    public let count: Int
    public let averageMs: Double
    public let minMs: Double
    public let maxMs: Double
    public let p50Ms: Double
    public let p95Ms: Double
    public let slowCount: Int

    public var slowRate: Double {
        guard count > 0 else { return 0 }
        return Double(slowCount) / Double(count)
    }

    public init(
        event: EditorPerfEvent,
        count: Int,
        averageMs: Double,
        minMs: Double,
        maxMs: Double,
        p50Ms: Double,
        p95Ms: Double,
        slowCount: Int
    ) {
        self.event = event
        self.count = count
        self.averageMs = averageMs
        self.minMs = minMs
        self.maxMs = maxMs
        self.p50Ms = p50Ms
        self.p95Ms = p95Ms
        self.slowCount = slowCount
    }
}

@MainActor
public final class EditorPerformance: SuperLog {
    public static let shared = EditorPerformance()

    private let logger = Logger(subsystem: "com.coffic.lumi", category: "editor.perf")
    private var recentResults: [EditorPerfResult] = []
    private static let maxResults = 1000
    private var activeSpans: [String: (event: EditorPerfEvent, start: TimeInterval)] = [:]

    public init() {}

    @discardableResult
    public func begin(_ event: EditorPerfEvent, metadata: [String: String] = [:]) -> String {
        let token = UUID().uuidString
        let now = CFAbsoluteTimeGetCurrent() * 1000
        activeSpans[token] = (event: event, start: now)
        return token
    }

    public func end(_ token: String, metadata: [String: String] = [:]) {
        guard let span = activeSpans.removeValue(forKey: token) else { return }
        let now = CFAbsoluteTimeGetCurrent() * 1000
        let duration = now - span.start

        let result = EditorPerfResult(
            event: span.event,
            duration: duration,
            timestamp: Date(),
            metadata: metadata
        )

        record(result)
    }

    public func cancel(_ token: String) {
        activeSpans.removeValue(forKey: token)
    }

    @discardableResult
    public func measure(_ event: EditorPerfEvent, metadata: [String: String] = [:], _ block: () -> Void) -> TimeInterval {
        let token = begin(event, metadata: metadata)
        block()
        end(token, metadata: metadata)
        return recentResults.last?.duration ?? 0
    }

    public func measure(_ event: EditorPerfEvent, metadata: [String: String] = [:], _ block: () async -> Void) async {
        let token = begin(event, metadata: metadata)
        await block()
        end(token, metadata: metadata)
    }

    public func summary(for event: EditorPerfEvent) -> EditorPerfSummary? {
        let results = recentResults.filter { $0.event == event }
        guard !results.isEmpty else { return nil }

        let durations = results.map(\.duration).sorted()
        let count = durations.count
        let sum = durations.reduce(0, +)
        let threshold = EditorPerfResult.slowThreshold(for: event)
        let slowCount = durations.filter { $0 > threshold }.count

        return EditorPerfSummary(
            event: event,
            count: count,
            averageMs: sum / Double(count),
            minMs: durations.first ?? 0,
            maxMs: durations.last ?? 0,
            p50Ms: durations[count / 2],
            p95Ms: durations[Int(Double(count) * 0.95)],
            slowCount: slowCount
        )
    }

    public func allSummaries() -> [EditorPerfSummary] {
        let events = Set(recentResults.map(\.event))
        return events.compactMap { summary(for: $0) }
            .sorted { $0.event.rawValue < $1.event.rawValue }
    }

    public func recentSlowEvents(limit: Int = 20) -> [EditorPerfResult] {
        let normalizedLimit = max(0, limit)
        guard normalizedLimit > 0 else { return [] }
        return recentResults.filter(\.isSlow).suffix(normalizedLimit).map { $0 }
    }

    public func clear() {
        recentResults.removeAll()
    }

    public func report() -> String {
        var lines: [String] = []
        lines.append("=== Editor Performance Report ===")
        lines.append("")

        let summaries = allSummaries()
        if summaries.isEmpty {
            lines.append("(no data)")
            return lines.joined(separator: "\n")
        }

        for s in summaries {
            let slowMarker = s.slowRate > 0.1 ? " ⚠️" : ""
            lines.append(String(format: "%-25@ count=%3d avg=%6.1fms p50=%6.1fms p95=%6.1fms max=%6.1fms slow=%d(%.0f%%)%@",
                s.event.rawValue,
                s.count,
                s.averageMs,
                s.p50Ms,
                s.p95Ms,
                s.maxMs,
                s.slowCount,
                s.slowRate * 100,
                slowMarker
            ))
        }

        let slowEvents = recentSlowEvents()
        if !slowEvents.isEmpty {
            lines.append("")
            lines.append("--- Recent Slow Events ---")
            for event in slowEvents.suffix(10) {
                let meta = event.metadata.isEmpty ? "" : " \(event.metadata)"
                lines.append(String(format: "  %@: %.1fms%@",
                    event.event.rawValue,
                    event.duration,
                    meta
                ))
            }
        }

        return lines.joined(separator: "\n")
    }

    private func record(_ result: EditorPerfResult) {
        recentResults.append(result)
        if recentResults.count > Self.maxResults {
            recentResults.removeFirst(recentResults.count - Self.maxResults)
        }

        if result.isSlow {
            logger.warning("\(self.t)⚡️ SLOW \(result.event.rawValue): \(String(format: "%.1f", result.duration))ms (threshold: \(String(format: "%.0f", EditorPerfResult.slowThreshold(for: result.event)))ms)")
        } else if result.duration > 1.0 {
            logger.debug("\(self.t)⏱ \(result.event.rawValue): \(String(format: "%.2f", result.duration))ms")
        }
    }
}
