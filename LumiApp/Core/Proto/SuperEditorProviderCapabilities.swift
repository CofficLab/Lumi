import Foundation
import AppKit
import Combine
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages
import LanguageServerProtocol

// MARK: - Editor LSP Provider Protocols

/// 编辑器 LSP 能力提供者协议族
///
/// 这些协议将具体 Provider 类型（如 `SignatureHelpProvider`、`InlayHintProvider` 等）
/// 抽象为内核可消费的接口。内核只依赖这些协议，不直接引用具体实现。
///
/// ## 注册流程
/// 1. LSP 子插件在 `registerEditorExtensions(into:)` 中创建并注册自己的 Provider
/// 2. `EditorExtensionRegistry` 聚合所有 Provider
/// 3. `EditorState` 从 registry 获取 Provider 实例

// MARK: - Signature Help Provider

@MainActor
protocol SuperEditorSignatureHelpProvider: AnyObject {
    var currentHelp: SignatureHelpItem? { get }
    var isLoading: Bool { get }
    var triggerCharacters: Set<String> { get }
    var isAvailable: Bool { get }

    func requestSignatureHelp(
        uri: String,
        line: Int,
        character: Int,
        preflight: (() -> Bool)?
    ) async
    func clear()
    func reset()
}

// MARK: - Inlay Hint Provider

@MainActor
protocol SuperEditorInlayHintProvider: AnyObject {
    var hints: [InlayHintItem] { get }
    var isAvailable: Bool { get }

    func requestHints(uri: String, startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async
    func requestFullDocumentHints(uri: String, lineCount: Int) async
    func clear()
    func reset()
}

// MARK: - Document Highlight Provider

@MainActor
protocol SuperEditorDocumentHighlightProvider: AnyObject {
    var highlightRanges: [NSRange] { get }
    var isActive: Bool { get }

    func requestHighlight(uri: String, line: Int, character: Int, content: String) async
    func clear()
    func reset()
}

// MARK: - Code Action Provider

@MainActor
protocol SuperEditorCodeActionProvider: AnyObject {
    var actions: [CodeActionItem] { get }
    var isLoading: Bool { get }
    var isVisible: Bool { get }

    func requestCodeActions(uri: String, range: LSPRange, diagnostics: [Diagnostic]) async
    func requestCodeActionsForLine(
        uri: String,
        line: Int,
        character: Int,
        diagnostics: [Diagnostic],
        languageId: String,
        selectedText: String?
    ) async
    func performAction(
        _ item: CodeActionItem,
        textView: TextView?,
        documentURL: URL?,
        applyWorkspaceEditViaTransaction: ((WorkspaceEdit) -> Void)?,
        onFailureMessage: (String) -> Void
    ) async
    func clear()
    func reset()
}

// MARK: - Workspace Symbol Provider

@MainActor
protocol SuperEditorWorkspaceSymbolProvider: AnyObject {
    var symbols: [WorkspaceSymbolItem] { get }
    var isSearching: Bool { get }
    var searchError: String? { get }
    var isAvailable: Bool { get }

    func searchSymbols(query: String) async
    func clear()
    func reset()
    func filterLocalResults(query: String) -> [WorkspaceSymbolItem]
}

// MARK: - Call Hierarchy Provider

@MainActor
protocol SuperEditorCallHierarchyProvider: AnyObject {
    var rootItem: EditorCallHierarchyItem? { get }
    var incomingCalls: [EditorCallHierarchyCall] { get }
    var outgoingCalls: [EditorCallHierarchyCall] { get }
    var isLoading: Bool { get }
    var isAvailable: Bool { get }

    func prepareCallHierarchy(uri: String, line: Int, character: Int) async
    func fetchIncomingCalls(item: EditorCallHierarchyItem) async
    func fetchOutgoingCalls(item: EditorCallHierarchyItem) async
    func clear()
    func reset()
}

// MARK: - Folding Range Provider

@MainActor
protocol SuperEditorFoldingRangeProvider: AnyObject {
    var ranges: [FoldingRangeItem] { get }
    var isAvailable: Bool { get }

    func requestRanges(uri: String) async
    func clear()
    func reset()
}

// MARK: - Document Symbol Provider

@MainActor
protocol SuperEditorDocumentSymbolProvider: AnyObject {
    var symbols: [EditorDocumentSymbolItem] { get }
    var isLoading: Bool { get }

    func refresh()
    func clear()
    func reset()
    func applySymbols(_ symbols: [EditorDocumentSymbolItem])
    func activeItems(for line: Int) -> [EditorDocumentSymbolItem]
    func activePathIDs(for line: Int) -> [String]
    func activeAncestorIDs(for line: Int) -> Set<String>
}

// MARK: - Semantic Token Provider

@MainActor
protocol SuperEditorSemanticTokenProvider: AnyObject {
    func setUp(textView: TextView, codeLanguage: CodeLanguage)
    func setEnabled(_ enabled: Bool)
    func scheduleViewportRefresh()
    func applyEdit(
        textView: TextView,
        range: NSRange,
        delta: Int,
        completion: @escaping @MainActor (Result<IndexSet, Error>) -> Void
    )
    func queryHighlightsFor(
        textView: TextView,
        range: NSRange,
        completion: @escaping @MainActor (Result<[HighlightRange], Error>) -> Void
    )
}

// MARK: - Diagnostics Provider

@MainActor
protocol SuperEditorLSPDiagnosticsProvider: AnyObject {
    var diagnosticsPublisher: AnyPublisher<[Diagnostic], Never> { get }
}

// MARK: - No-Op Default Implementations

/// 用于 registry 未注册对应 provider 时的安全占位实现
/// 所有方法均为空操作，所有属性返回空/默认值

@MainActor
final class NullSignatureHelpProvider: ObservableObject, SuperEditorSignatureHelpProvider {
    var currentHelp: SignatureHelpItem? { nil }
    var isLoading: Bool { false }
    var triggerCharacters: Set<String> { [] }
    var isAvailable: Bool { false }
    func requestSignatureHelp(uri: String, line: Int, character: Int, preflight: (() -> Bool)?) async {}
    func clear() {}
    func reset() {}
}

@MainActor
final class NullInlayHintProvider: ObservableObject, SuperEditorInlayHintProvider {
    var hints: [InlayHintItem] { [] }
    var isAvailable: Bool { false }
    func requestHints(uri: String, startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async {}
    func requestFullDocumentHints(uri: String, lineCount: Int) async {}
    func clear() {}
    func reset() {}
}

@MainActor
final class NullDocumentHighlightProvider: ObservableObject, SuperEditorDocumentHighlightProvider {
    var highlightRanges: [NSRange] { [] }
    var isActive: Bool { false }
    func requestHighlight(uri: String, line: Int, character: Int, content: String) async {}
    func clear() {}
    func reset() {}
}

@MainActor
final class NullCodeActionProvider: ObservableObject, SuperEditorCodeActionProvider {
    var actions: [CodeActionItem] { [] }
    var isLoading: Bool { false }
    var isVisible: Bool { false }
    func requestCodeActions(uri: String, range: LSPRange, diagnostics: [Diagnostic]) async {}
    func requestCodeActionsForLine(uri: String, line: Int, character: Int, diagnostics: [Diagnostic], languageId: String, selectedText: String?) async {}
    func performAction(_ item: CodeActionItem, textView: TextView?, documentURL: URL?, applyWorkspaceEditViaTransaction: ((WorkspaceEdit) -> Void)?, onFailureMessage: (String) -> Void) async {}
    func clear() {}
    func reset() {}
}

@MainActor
final class NullWorkspaceSymbolProvider: ObservableObject, SuperEditorWorkspaceSymbolProvider {
    var symbols: [WorkspaceSymbolItem] { [] }
    var isSearching: Bool { false }
    var searchError: String? { nil }
    var isAvailable: Bool { false }
    func searchSymbols(query: String) async {}
    func clear() {}
    func reset() {}
    func filterLocalResults(query: String) -> [WorkspaceSymbolItem] { [] }
}

@MainActor
final class NullCallHierarchyProvider: ObservableObject, SuperEditorCallHierarchyProvider {
    var rootItem: EditorCallHierarchyItem? { nil }
    var incomingCalls: [EditorCallHierarchyCall] { [] }
    var outgoingCalls: [EditorCallHierarchyCall] { [] }
    var isLoading: Bool { false }
    var isAvailable: Bool { false }
    func prepareCallHierarchy(uri: String, line: Int, character: Int) async {}
    func fetchIncomingCalls(item: EditorCallHierarchyItem) async {}
    func fetchOutgoingCalls(item: EditorCallHierarchyItem) async {}
    func clear() {}
    func reset() {}
}

@MainActor
final class NullFoldingRangeProvider: ObservableObject, SuperEditorFoldingRangeProvider {
    var ranges: [FoldingRangeItem] { [] }
    var isAvailable: Bool { false }
    func requestRanges(uri: String) async {}
    func clear() {}
    func reset() {}
}

@MainActor
final class NullDocumentSymbolProvider: ObservableObject, SuperEditorDocumentSymbolProvider {
    var symbols: [EditorDocumentSymbolItem] { [] }
    var isLoading: Bool { false }
    func refresh() {}
    func clear() {}
    func reset() {}
    func applySymbols(_ symbols: [EditorDocumentSymbolItem]) {}
    func activeItems(for line: Int) -> [EditorDocumentSymbolItem] { [] }
    func activePathIDs(for line: Int) -> [String] { [] }
    func activeAncestorIDs(for line: Int) -> Set<String> { [] }
}

@MainActor
final class NullDiagnosticsProvider: ObservableObject, SuperEditorLSPDiagnosticsProvider {
    var diagnosticsPublisher: AnyPublisher<[Diagnostic], Never> { Just([]).eraseToAnyPublisher() }
}

// MARK: - Provider Collection

/// 从插件注册中心获取的 Provider 集合
@MainActor
struct EditorLSPProviderSet {
    var signatureHelpProvider: (any SuperEditorSignatureHelpProvider)?
    var inlayHintProvider: (any SuperEditorInlayHintProvider)?
    var documentHighlightProvider: (any SuperEditorDocumentHighlightProvider)?
    var codeActionProvider: (any SuperEditorCodeActionProvider)?
    var workspaceSymbolProvider: (any SuperEditorWorkspaceSymbolProvider)?
    var callHierarchyProvider: (any SuperEditorCallHierarchyProvider)?
    var foldingRangeProvider: (any SuperEditorFoldingRangeProvider)?
    var documentSymbolProvider: (any SuperEditorDocumentSymbolProvider)?
    var semanticTokenProvider: (any SuperEditorSemanticTokenProvider)?
    var diagnosticsProvider: (any SuperEditorLSPDiagnosticsProvider)?
}
