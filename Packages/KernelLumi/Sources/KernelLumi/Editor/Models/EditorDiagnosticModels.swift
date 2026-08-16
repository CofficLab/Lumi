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

/// 语义问题（项目上下文/语言服务的可用性提示，非诊断）。
///
/// 如「项目索引不可用」「语义引擎降级」等宿主状态说明；
/// 与按文档的诊断互补，Problems 面板附加展示。
public struct EditorSemanticProblem: Identifiable, Equatable, Sendable {
    public enum Severity: String, Equatable, Sendable {
        case info
        case warning
        case error
    }

    public let id: String

    public let severity: Severity

    public let title: String

    public let message: String

    public init(id: String, severity: Severity, title: String, message: String) {
        self.id = id
        self.severity = severity
        self.title = title
        self.message = message
    }
}

/// 诊断快照（State，可随时读取与重放，§8.9）。
///
/// 当前阶段诊断按活动文档聚合（与底层 LSP 管线一致）；
/// 多文档聚合在 LSP 管线支持后自然扩展，消费者不应假设只含活动文档。
public struct EditorDiagnosticsSnapshot: Equatable, Sendable {
    public let diagnostics: [EditorDiagnosticItem]

    /// 语义问题（项目级，不隶属单个文档）。
    public let semanticProblems: [EditorSemanticProblem]

    public init(
        diagnostics: [EditorDiagnosticItem],
        semanticProblems: [EditorSemanticProblem] = []
    ) {
        self.diagnostics = diagnostics
        self.semanticProblems = semanticProblems
    }

    public static let empty = EditorDiagnosticsSnapshot(diagnostics: [])

    public var errorCount: Int {
        diagnostics.filter { $0.severity == .error }.count
    }

    public var warningCount: Int {
        diagnostics.filter { $0.severity == .warning }.count
    }
}

// MARK: - 跨包消歧别名

/// `EditorSemanticProblem`（V2 契约）的消歧别名。
///
/// EditorService 等包 re-export 了 EditorKernel 的同名历史类型，
/// 未限定名会解析到历史类型一侧；需要同时引用两侧的包使用本别名。
public typealias EditorV2SemanticProblem = EditorSemanticProblem
