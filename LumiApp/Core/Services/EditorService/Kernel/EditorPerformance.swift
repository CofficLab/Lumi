import Foundation
import os

// MARK: - Editor Performance Metrics
//
// Phase 0 遗留项：性能基线指标。
//
// 建立量化指标体系，用于：
// 1. 度量编辑器关键操作的耗时
// 2. 检测性能回归
// 3. 为大文件/高频操作场景提供优化依据
//
// 使用 `os.signpost` / `os.Logger` 实现，与 Instruments 无缝配合。
// 所有度量均为非侵入式，不影响主流程性能。

/// 性能度量事件类型
enum EditorPerfEvent: String, Sendable {
    // 文件操作
    case fileOpen = "file.open"                  // 打开文件总耗时
    case fileOpenRead = "file.open.read"         // 读取文件内容耗时
    case fileOpenDetect = "file.open.detect"     // 语言检测耗时
    case fileOpenLSP = "file.open.lsp"           // LSP openFile 耗时
    case fileOpenRender = "file.open.render"     // 首次渲染耗时
    case fileSave = "file.save"                  // 保存文件总耗时
    case fileSavePipeline = "file.save.pipeline" // 保存管线（trim/format）耗时

    // 编辑操作
    case editTransaction = "edit.transaction"    // 编辑事务应用耗时
    case editFormat = "edit.format"              // 格式化文档耗时
    case editRename = "edit.rename"              // 重命名符号耗时
    case editCodeAction = "edit.codeAction"      // Code Action 应用耗时
    case editLineEdit = "edit.lineEdit"          // 行编辑命令耗时

    // 语言服务
    case lspCompletion = "lsp.completion"        // 补全请求耗时
    case lspHover = "lsp.hover"                  // Hover 请求耗时
    case lspDiagnostics = "lsp.diagnostics"      // 诊断更新耗时
    case lspInlayHints = "lsp.inlayHints"        // Inlay Hints 请求耗时
    case lspReferences = "lsp.references"        // 查找引用耗时
    case lspSignatureHelp = "lsp.signatureHelp"  // 签名帮助耗时

    // 渲染
    case renderViewport = "render.viewport"      // Viewport 更新耗时
    case renderBracketMatch = "render.bracket"   // 括号匹配计算耗时
    case renderSyntaxHighlight = "render.syntax" // 语法高亮更新耗时
    case renderFindMatches = "render.find"       // 查找匹配计算耗时

    // 会话
    case sessionSwitch = "session.switch"        // Tab 切换耗时
    case sessionRestore = "session.restore"      // 会话状态恢复耗时
}

/// 性能度量结果
struct EditorPerfResult: Sendable {
    let event: EditorPerfEvent
    let duration: TimeInterval  // 毫秒
    let timestamp: Date
    let metadata: [String: String]

    var isSlow: Bool {
        duration > Self.slowThreshold(for: event)
    }

    /// 各类操作的慢速阈值（毫秒）
    static func slowThreshold(for event: EditorPerfEvent) -> TimeInterval {
        switch event {
        // 文件操作：500ms 为可感知延迟
        case .fileOpen: return 500
        case .fileOpenRead: return 200
        case .fileOpenDetect: return 50
        case .fileOpenLSP: return 300
        case .fileOpenRender: return 200
        case .fileSave: return 300
        case .fileSavePipeline: return 200

        // 编辑操作：100ms 为即时反馈上限
        case .editTransaction: return 16      // 一帧（60fps）
        case .editFormat: return 500
        case .editRename: return 500
        case .editCodeAction: return 200
        case .editLineEdit: return 16

        // 语言服务：200ms 为合理等待上限
        case .lspCompletion: return 200
        case .lspHover: return 300
        case .lspDiagnostics: return 500
        case .lspInlayHints: return 500
        case .lspReferences: return 500
        case .lspSignatureHelp: return 300

        // 渲染：16ms 为一帧上限
        case .renderViewport: return 16
        case .renderBracketMatch: return 5
        case .renderSyntaxHighlight: return 50
        case .renderFindMatches: return 50

        // 会话：100ms 为可接受切换延迟
        case .sessionSwitch: return 100
        case .sessionRestore: return 100
        }
    }
}

/// 性能统计摘要
struct EditorPerfSummary: Sendable {
    let event: EditorPerfEvent
    let count: Int
    let averageMs: Double
    let minMs: Double
    let maxMs: Double
    let p50Ms: Double     // 中位数
    let p95Ms: Double     // 95 分位
    let slowCount: Int    // 超过阈值的次数

    var slowRate: Double {
        guard count > 0 else { return 0 }
        return Double(slowCount) / Double(count)
    }
}

/// 编辑器性能度量器
///
/// 使用方法：
/// ```swift
/// let token = EditorPerformance.begin(.fileOpen)
/// // ... 执行操作 ...
/// EditorPerformance.end(token, metadata: ["fileSize": "\(size)"])
/// ```
///
/// 也可以用 convenience 方法：
/// ```swift
/// EditorPerformance.measure(.editFormat) {
///     await formatDocument()
/// }
/// ```
@MainActor
final class EditorPerformance {
    static let shared = EditorPerformance()

    private let logger = Logger(subsystem: "com.coffic.lumi", category: "editor.perf")

    /// 最近的度量结果（保留最近 1000 条）
    private var recentResults: [EditorPerfResult] = []
    private static let maxResults = 1000

    /// 进行中的度量
    private var activeSpans: [String: (event: EditorPerfEvent, start: TimeInterval)] = [:]

    private init() {}

    // MARK: - Span-based API

    /// 开始度量一个操作
    @discardableResult
    func begin(_ event: EditorPerfEvent, metadata: [String: String] = [:]) -> String {
        let token = UUID().uuidString
        let now = CFAbsoluteTimeGetCurrent() * 1000  // 毫秒
        activeSpans[token] = (event: event, start: now)
        return token
    }

    /// 结束度量一个操作
    func end(_ token: String, metadata: [String: String] = [:]) {
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

    /// 取消一个度量（不记录结果）
    func cancel(_ token: String) {
        activeSpans.removeValue(forKey: token)
    }

    // MARK: - Convenience API

    /// 同步度量一个操作
    @discardableResult
    func measure(_ event: EditorPerfEvent, metadata: [String: String] = [:], _ block: () -> Void) -> TimeInterval {
        let token = begin(event, metadata: metadata)
        block()
        end(token, metadata: metadata)
        // 返回最近记录的耗时
        return recentResults.last?.duration ?? 0
    }

    /// 异步度量一个操作
    func measure(_ event: EditorPerfEvent, metadata: [String: String] = [:], _ block: () async -> Void) async {
        let token = begin(event, metadata: metadata)
        await block()
        end(token, metadata: metadata)
    }

    // MARK: - Recording

    private func record(_ result: EditorPerfResult) {
        recentResults.append(result)
        if recentResults.count > Self.maxResults {
            recentResults.removeFirst(recentResults.count - Self.maxResults)
        }

        if result.isSlow {
            logger.warning("⚡️ SLOW \(result.event.rawValue): \(String(format: "%.1f", result.duration))ms (threshold: \(String(format: "%.0f", EditorPerfResult.slowThreshold(for: result.event)))ms)")
        } else if result.duration > 1.0 {
            logger.debug("⏱ \(result.event.rawValue): \(String(format: "%.2f", result.duration))ms")
        }
    }

    // MARK: - Query

    /// 获取指定事件类型的统计摘要
    func summary(for event: EditorPerfEvent) -> EditorPerfSummary? {
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

    /// 获取所有事件类型的统计摘要
    func allSummaries() -> [EditorPerfSummary] {
        let events = Set(recentResults.map(\.event))
        return events.compactMap { summary(for: $0) }
        .sorted { $0.event.rawValue < $1.event.rawValue }
    }

    /// 获取最近的慢速操作
    func recentSlowEvents(limit: Int = 20) -> [EditorPerfResult] {
        recentResults.filter(\.isSlow).suffix(limit).map { $0 }
    }

    /// 清除所有度量数据
    func clear() {
        recentResults.removeAll()
    }

    /// 生成性能报告
    func report() -> String {
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
            lines.append(String(format: "%-25s count=%3d avg=%6.1fms p50=%6.1fms p95=%6.1fms max=%6.1fms slow=%d(%.0f%%)%@",
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
}
