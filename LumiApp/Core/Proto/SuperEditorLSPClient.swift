import Foundation
import LanguageServerProtocol

/// 编辑器侧 LSP 客户端抽象
/// 作为 Editor 与具体 LSP 实现之间的解耦边界，便于后续独立 Plugin 化。
///
/// ## 设计原则
/// - 内核只依赖此协议，不 import / 不直接引用具体 LSP 实现
/// - 插件通过 `EditorExtensionRegistry.registerSuperEditorLSPClient()` 注册实现者
/// - 所有方法均为 @MainActor，保证与编辑器线程模型一致
@MainActor
public protocol SuperEditorLSPClient: AnyObject {
    // MARK: - 文件生命周期
    func setProjectRootPath(_ path: String?)
    func openFile(uri: String, languageId: String, content: String, version: Int) async
    func closeFile()
    func updateDocumentSnapshot(_ content: String)
    func contentDidChange(range: LSPRange, text: String, version: Int)
    func replaceDocument(_ content: String, version: Int)

    // MARK: - 补全
    func requestCompletion(line: Int, character: Int) async -> [CompletionItem]
    func requestCompletionDebounced(line: Int, character: Int) async -> [CompletionItem]
    func completionTriggerCharacters() -> Set<String>

    // MARK: - Hover
    func requestHoverRaw(line: Int, character: Int) async -> Hover?
    func requestHoverRawDebounced(line: Int, character: Int) async -> Hover?

    // MARK: - 跳转
    func requestDefinition(line: Int, character: Int) async -> Location?
    func requestDeclaration(line: Int, character: Int) async -> Location?
    func requestTypeDefinition(line: Int, character: Int) async -> Location?
    func requestImplementation(line: Int, character: Int) async -> Location?
    func requestReferences(line: Int, character: Int) async -> [Location]

    // MARK: - 符号
    func requestDocumentSymbols() async -> [DocumentSymbol]
    func requestWorkspaceSymbols(query: String) async -> WorkspaceSymbolResponse

    // MARK: - 高亮 & Signature & Inlay
    func requestDocumentHighlight(line: Int, character: Int) async -> [DocumentHighlight]
    func requestDocumentHighlightThrottled(line: Int, character: Int) async -> [DocumentHighlight]
    func requestSignatureHelp(line: Int, character: Int) async -> SignatureHelp?
    func requestSignatureHelpDebounced(line: Int, character: Int) async -> SignatureHelp?
    func requestInlayHint(startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async -> [InlayHint]?
    func requestInlayHintThrottled(startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async -> [InlayHint]?

    // MARK: - 代码动作
    func requestCodeAction(range: LSPRange, diagnostics: [Diagnostic], triggerKinds: [CodeActionKind]?) async -> [CodeAction]
    func requestCodeActionDebounced(range: LSPRange, diagnostics: [Diagnostic], triggerKinds: [CodeActionKind]?) async -> [CodeAction]
    func resolveCodeAction(_ action: CodeAction) async -> CodeAction?

    // MARK: - 折叠 & 格式化 & 重命名
    func requestFoldingRange() async -> [FoldingRange]
    func requestFoldingRangeDebounced() async -> [FoldingRange]
    func requestFormatting(tabSize: Int, insertSpaces: Bool) async -> [TextEdit]?
    func requestRename(line: Int, character: Int, newName: String) async -> WorkspaceEdit?

    // MARK: - 调用层级
    func requestCallHierarchy(line: Int, character: Int) async

    // MARK: - 选择范围 & 文档链接 & 颜色
    func requestSelectionRange(line: Int, character: Int) async -> [SelectionRange]
    func requestDocumentLinks() async -> [DocumentLink]
    func requestDocumentColors() async -> [ColorInformation]

    // MARK: - 文档生命周期事件
    func documentDidSave(uri: String, text: String?)

    // MARK: - 命令
    func executeCommand(command: String, arguments: [LSPAny]?) async -> LSPAny?

    // MARK: - 进度提供者
    var hasActiveWork: Bool { get }
    var supportsInlayHints: Bool { get }
    var supportsWillSave: Bool { get }
    var supportsWillSaveWaitUntil: Bool { get }
    var codeActionResolveSupported: Bool { get }
    var isAvailable: Bool { get }
}

// MARK: - Null Implementation

/// 无操作 LSP 客户端 — 内核默认值，不依赖任何插件
/// 当 LSPServiceEditorPlugin 未安装或未启用时使用此实现
@MainActor
final class NullLSPClient: SuperEditorLSPClient {
    func setProjectRootPath(_ path: String?) {}
    func openFile(uri: String, languageId: String, content: String, version: Int) async {}
    func closeFile() {}
    func updateDocumentSnapshot(_ content: String) {}
    func contentDidChange(range: LSPRange, text: String, version: Int) {}
    func replaceDocument(_ content: String, version: Int) {}

    func requestCompletion(line: Int, character: Int) async -> [CompletionItem] { [] }
    func requestCompletionDebounced(line: Int, character: Int) async -> [CompletionItem] { [] }
    func completionTriggerCharacters() -> Set<String> { [] }

    func requestHoverRaw(line: Int, character: Int) async -> Hover? { nil }
    func requestHoverRawDebounced(line: Int, character: Int) async -> Hover? { nil }

    func requestDefinition(line: Int, character: Int) async -> Location? { nil }
    func requestDeclaration(line: Int, character: Int) async -> Location? { nil }
    func requestTypeDefinition(line: Int, character: Int) async -> Location? { nil }
    func requestImplementation(line: Int, character: Int) async -> Location? { nil }
    func requestReferences(line: Int, character: Int) async -> [Location] { [] }

    func requestDocumentSymbols() async -> [DocumentSymbol] { [] }
    func requestWorkspaceSymbols(query: String) async -> WorkspaceSymbolResponse { nil }

    func requestDocumentHighlight(line: Int, character: Int) async -> [DocumentHighlight] { [] }
    func requestDocumentHighlightThrottled(line: Int, character: Int) async -> [DocumentHighlight] { [] }
    func requestSignatureHelp(line: Int, character: Int) async -> SignatureHelp? { nil }
    func requestSignatureHelpDebounced(line: Int, character: Int) async -> SignatureHelp? { nil }
    func requestInlayHint(startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async -> [InlayHint]? { nil }
    func requestInlayHintThrottled(startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async -> [InlayHint]? { nil }

    func requestCodeAction(range: LSPRange, diagnostics: [Diagnostic], triggerKinds: [CodeActionKind]?) async -> [CodeAction] { [] }
    func requestCodeActionDebounced(range: LSPRange, diagnostics: [Diagnostic], triggerKinds: [CodeActionKind]?) async -> [CodeAction] { [] }
    func resolveCodeAction(_ action: CodeAction) async -> CodeAction? { nil }

    func requestFoldingRange() async -> [FoldingRange] { [] }
    func requestFoldingRangeDebounced() async -> [FoldingRange] { [] }
    func requestFormatting(tabSize: Int, insertSpaces: Bool) async -> [TextEdit]? { nil }
    func requestRename(line: Int, character: Int, newName: String) async -> WorkspaceEdit? { nil }

    func requestCallHierarchy(line: Int, character: Int) async {}

    func requestSelectionRange(line: Int, character: Int) async -> [SelectionRange] { [] }
    func requestDocumentLinks() async -> [DocumentLink] { [] }
    func requestDocumentColors() async -> [ColorInformation] { [] }

    func documentDidSave(uri: String, text: String?) {}

    func executeCommand(command: String, arguments: [LSPAny]?) async -> LSPAny? { nil }

    var hasActiveWork: Bool { false }
    var supportsInlayHints: Bool { false }
    var supportsWillSave: Bool { false }
    var supportsWillSaveWaitUntil: Bool { false }
    var codeActionResolveSupported: Bool { false }
    var isAvailable: Bool { false }
}
