import EditorService
import Foundation
import LanguageServerProtocol
import Testing
@testable import LSPRealtimeSignalsPlugin

@MainActor
@Test func enumDotCompletionStillUsesLSPWhenSoftPreflightFails() async throws {
    let content = "let status: Status = ."
    let cursorOffset = content.utf16.count
    let cursorPosition = CursorPosition(line: 1, column: cursorOffset + 1)

    let lspClient = MockEnumCompletionLSPClient()
    lspClient.completionItems = [
        CompletionItem(label: "active", kind: .enumMember, insertText: "active"),
        CompletionItem(label: "inactive", kind: .enumMember, insertText: "inactive"),
    ]

    let registry = EditorExtensionRegistry()
    registry.registerCompletionContributor(MockSwiftBuiltinCompletionContributor())

    let session = MockLSPCompletionSession()
    session.currentFileURL = URL(fileURLWithPath: "/tmp/Status.swift")
    session.semanticCapability = MockSemanticCapability(
        preflightError: EditorLanguageFeatureError(
            domain: "xcode.semantic",
            code: "file-not-in-target",
            message: "File not in target",
            suggestion: nil
        )
    )

    let delegate = LSPCompletionDelegate()
    let result = await delegate.resolveCompletion(
        content: content,
        cursorOffset: cursorOffset,
        cursorPosition: cursorPosition,
        lspClient: lspClient,
        registry: registry,
        session: session
    )

    #expect(lspClient.requestCompletionCalled)
    #expect(result?.items.count == 2)
    #expect(result?.items.map(\.label).contains("active") == true)
}

@MainActor
@Test func enumDotCompletionUsesLSPWhenPreflightPasses() async throws {
    let content = "let status: Status = ."
    let cursorOffset = content.utf16.count
    let cursorPosition = CursorPosition(line: 1, column: cursorOffset + 1)

    let lspClient = MockEnumCompletionLSPClient()
    lspClient.completionItems = [
        CompletionItem(label: "active", kind: .enumMember, insertText: "active"),
        CompletionItem(label: "inactive", kind: .enumMember, insertText: "inactive"),
    ]

    let registry = EditorExtensionRegistry()
    registry.registerCompletionContributor(MockSwiftBuiltinCompletionContributor())

    let session = MockLSPCompletionSession()
    session.currentFileURL = URL(fileURLWithPath: "/tmp/Status.swift")
    session.semanticCapability = MockSemanticCapability(preflightError: nil)

    let delegate = LSPCompletionDelegate()
    let result = await delegate.resolveCompletion(
        content: content,
        cursorOffset: cursorOffset,
        cursorPosition: cursorPosition,
        lspClient: lspClient,
        registry: registry,
        session: session
    )

    #expect(lspClient.requestCompletionCalled)
    #expect(result?.items.count == 2)
    #expect(result?.items.map(\.label).contains("active") == true)
    #expect(result?.items.map(\.label).contains("inactive") == true)
}

@MainActor
@Test func typeContextStillUsesPluginFallbackWhenPreflightBlocksLSP() async throws {
    let content = "let id: In"
    let cursorOffset = content.utf16.count
    let cursorPosition = CursorPosition(line: 1, column: cursorOffset + 1)

    let lspClient = MockEnumCompletionLSPClient()

    let registry = EditorExtensionRegistry()
    registry.registerCompletionContributor(MockSwiftBuiltinCompletionContributor())

    let session = MockLSPCompletionSession()
    session.currentFileURL = URL(fileURLWithPath: "/tmp/Types.swift")
    session.semanticCapability = MockSemanticCapability(
        preflightError: EditorLanguageFeatureError(
            domain: "xcode.semantic",
            code: "build-context-unavailable",
            message: "Build context unavailable",
            suggestion: nil
        )
    )

    let delegate = LSPCompletionDelegate()
    let result = await delegate.resolveCompletion(
        content: content,
        cursorOffset: cursorOffset,
        cursorPosition: cursorPosition,
        lspClient: lspClient,
        registry: registry,
        session: session
    )

    #expect(lspClient.requestCompletionCalled == false)
    #expect(result != nil)
    #expect(result?.items.contains { $0.label == "Int" } == true)
}

// MARK: - Test Doubles

/// Mirrors built-in Swift primitive type contributor behavior for tests.
@MainActor
private final class MockSwiftBuiltinCompletionContributor: SuperEditorCompletionContributor {
    let id = "test.swift.primitive-types"

    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        guard context.languageId.lowercased() == "swift", context.isTypeContext else { return [] }
        let types = ["Int", "String", "Bool"]
        guard context.prefix.isEmpty else {
            return types
                .filter { $0.lowercased().hasPrefix(context.prefix.lowercased()) }
                .map { EditorCompletionSuggestion(label: $0, insertText: $0, detail: nil, priority: 100) }
        }
        return types.map { EditorCompletionSuggestion(label: $0, insertText: $0, detail: nil, priority: 100) }
    }
}

@MainActor
private final class MockLSPCompletionSession: LSPCompletionSessionContext {
    var currentFileURL: URL?
    var languageId = "swift"
    var semanticCapability: (any SuperEditorSemanticCapability)?
}

@MainActor
private final class MockSemanticCapability: SuperEditorSemanticCapability {
    let id = "mock.semantic"
    private let preflightError: EditorLanguageFeatureError?

    init(preflightError: EditorLanguageFeatureError?) {
        self.preflightError = preflightError
    }

    func inspectCurrentFileContext(uri: String?) -> EditorSemanticAvailabilityReport {
        EditorSemanticAvailabilityReport(reasons: [])
    }

    func preflightMessage(
        uri: String?,
        operation: String,
        symbolName: String?,
        strength: EditorSemanticPreflightStrength
    ) -> String? {
        nil
    }

    func preflightError(
        uri: String?,
        operation: String,
        symbolName: String?,
        strength: EditorSemanticPreflightStrength
    ) -> EditorLanguageFeatureError? {
        preflightError
    }
}

@MainActor
private final class MockEnumCompletionLSPClient: SuperEditorLSPClient {
    var completionItems: [CompletionItem] = []
    private(set) var requestCompletionCalled = false

    var hasActiveWork: Bool { false }
    var supportsInlayHints: Bool { false }
    var supportsWillSave: Bool { false }
    var supportsWillSaveWaitUntil: Bool { false }
    var codeActionResolveSupported: Bool { false }
    var isAvailable: Bool { true }

    func setProjectRootPath(_ path: String?) {}
    func closeFile() {}
    func updateDocumentSnapshot(_ content: String) {}
    func contentDidChange(range: LSPRange, text: String, version: Int) {}
    func replaceDocument(_ content: String, version: Int) {}
    func openFile(uri: String, languageId: String, content: String, version: Int) async {}

    func requestCompletion(line: Int, character: Int) async -> [CompletionItem] {
        requestCompletionCalled = true
        return completionItems
    }

    func requestCompletionDebounced(line: Int, character: Int) async -> [CompletionItem] {
        await requestCompletion(line: line, character: character)
    }

    func completionTriggerCharacters() -> Set<String> { ["."] }
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
    func resolveDocumentLink(_ link: DocumentLink) async -> DocumentLink? { nil }
    func requestSemanticTokens() async -> SemanticTokens? { nil }
    func documentWillSave(reason: TextDocumentSaveReason) async {}
    func documentWillSaveWaitUntil(reason: TextDocumentSaveReason) async -> [TextEdit]? { nil }
    func documentDidSave(uri: String, text: String?) {}
    func executeCommand(command: String, arguments: [LSPAny]?) async -> LSPAny? { nil }
}
