import Foundation

// MARK: - 诊断模型（契约 V2）

/// 诊断严重级别（中立枚举，不泄露 LSP 类型）。
public enum EditorDiagnosticSeverity: Equatable, Hashable, Sendable, CaseIterable {
    case error
    case warning
    case information
    case hint
}

/// 单条诊断（值类型快照，见重构方案 §7）。
public struct EditorDiagnosticItem: Identifiable, Equatable, Sendable {
    /// 稳定标识：`uri#line-character-severity-message`。
    public let id: String

    /// 诊断所属文档 URI。
    public let documentURI: URL

    /// 诊断范围（zero-based UTF-16）。
    public let range: EditorRange

    public let severity: EditorDiagnosticSeverity

    public let message: String

    /// 诊断来源（如 `"sourcekit-lsp"`）。
    public let source: String?

    /// 诊断代码（如规则编号）。
    public let code: String?

    public init(
        id: String,
        documentURI: URL,
        range: EditorRange,
        severity: EditorDiagnosticSeverity,
        message: String,
        source: String? = nil,
        code: String? = nil
    ) {
        self.id = id
        self.documentURI = documentURI
        self.range = range
        self.severity = severity
        self.message = message
        self.source = source
        self.code = code
    }

    /// 起始行（1-based，便于 UI 展示分组）。
    public var lineNumber: Int { range.start.line + 1 }
}

/// 诊断快照（State，可随时读取与重放，§8.9）。
///
/// 当前阶段诊断按活动文档聚合（与底层 LSP 管线一致）；
/// 多文档聚合在 LSP 管线支持后自然扩展，消费者不应假设只含活动文档。
public struct EditorDiagnosticsSnapshot: Equatable, Sendable {
    public let diagnostics: [EditorDiagnosticItem]

    public init(diagnostics: [EditorDiagnosticItem]) {
        self.diagnostics = diagnostics
    }

    public static let empty = EditorDiagnosticsSnapshot(diagnostics: [])

    public var errorCount: Int {
        diagnostics.filter { $0.severity == .error }.count
    }

    public var warningCount: Int {
        diagnostics.filter { $0.severity == .warning }.count
    }
}
