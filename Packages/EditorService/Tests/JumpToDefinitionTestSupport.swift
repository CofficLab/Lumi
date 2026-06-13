#if canImport(XCTest)
import EditorSource
import EditorLanguages
import EditorTextView
import Foundation
import LanguageServerProtocol
import SwiftTreeSitter
import XCTest
@testable import EditorService

@MainActor
enum JumpToDefinitionTestSupport {
    static let greetFixture = """
    func greet() {
        print("hello")
    }

    func usage() {
        greet()
    }
    """

    static let laterDefinitionFixture = """
    func usage() {
        speak()
    }

    func speak() {
        print("ok")
    }
    """

    static let regexFixture = """
    func hello() {
    }

    func call() {
        hello()
    }
    """

    static func swiftLanguage() -> CodeLanguage {
        CodeLanguage.allLanguages.first { $0.tsName == "swift" } ?? CodeLanguage.allLanguages[0]
    }

    static func symbolRange(in text: String, symbol: String, occurrence: Int = 0) -> NSRange {
        let nsText = text as NSString
        var searchRange = NSRange(location: 0, length: nsText.length)
        var found = 0

        while searchRange.length > 0 {
            let range = nsText.range(of: symbol, options: [], range: searchRange)
            XCTAssertNotEqual(range.location, NSNotFound, "Symbol '\(symbol)' occurrence \(occurrence) not found")
            if found == occurrence {
                return range
            }
            found += 1
            let nextLocation = range.location + range.length
            searchRange = NSRange(
                location: nextLocation,
                length: max(0, nsText.length - nextLocation)
            )
        }

        XCTFail("Symbol '\(symbol)' occurrence \(occurrence) not found")
        return NSRange(location: 0, length: 0)
    }

    static func parseSwiftTree(for content: String) throws -> (MutableTree, Node) {
        let language = swiftLanguage()
        try XCTSkipIf(
            language.language == nil,
            "tree_sitter_swift is unavailable; build CodeLanguagesContainer.xcframework with ./build_framework.sh"
        )
        guard let parserLanguage = language.language else {
            throw ParseError.missingLanguage
        }
        let parser = Parser()
        try parser.setLanguage(parserLanguage)
        guard let tree = parser.parse(content), let root = tree.rootNode else {
            throw ParseError.missingTree
        }
        return (tree, root)
    }

    static func cursorNode(in tree: MutableTree, at location: Int, content: String) throws -> Node {
        guard let start = utf8ByteOffset(at: location, in: content),
              let end = utf8ByteOffset(at: location + 1, in: content),
              let node = tree.rootNode?.descendant(in: start..<end) else {
            throw ParseError.missingCursorNode
        }
        return node
    }

    private static func utf8ByteOffset(at utf16Location: Int, in content: String) -> UInt32? {
        guard utf16Location >= 0, utf16Location <= content.utf16.count else { return nil }
        var utf16Consumed = 0
        var utf8Offset = 0
        for scalar in content.unicodeScalars {
            if utf16Consumed >= utf16Location {
                break
            }
            utf16Consumed += scalar.utf16.count
            utf8Offset += scalar.utf8.count
        }
        return UInt32(utf8Offset)
    }

    static func makeConfiguration() -> SourceEditorConfiguration {
        SourceEditorConfiguration(
            appearance: .init(
                theme: EditorThemeAdapter.fallbackTheme(),
                font: .monospacedSystemFont(ofSize: 12, weight: .regular),
                wrapLines: true
            )
        )
    }

    static func makeController(content: String) -> TextViewController {
        let controller = TextViewController(
            string: content,
            language: swiftLanguage(),
            configuration: makeConfiguration(),
            cursorPositions: [],
            highlightProviders: []
        )
        controller.loadView()
        return controller
    }

    static func makeDelegate(
        content: String,
        lspClient: (any SuperEditorLSPClient)? = nil,
        lspClientProvider: (() -> (any SuperEditorLSPClient)?)? = nil,
        structuredProject: Bool = false,
        fileURL: URL = URL(fileURLWithPath: "/tmp/JumpToDefinitionTests/TestFile.swift")
    ) -> (delegate: EditorJumpToDefinitionDelegate, controller: TextViewController) {
        let controller = makeController(content: content)
        let delegate = EditorJumpToDefinitionDelegate()
        delegate.textStorage = controller.textView.textStorage
        delegate.textViewController = controller
        delegate.lspClient = lspClient
        delegate.lspClientProvider = lspClientProvider ?? { lspClient }
        delegate.currentFileURLProvider = { fileURL }
        delegate.allowsLocalFallbackProvider = { !structuredProject }
        return (delegate, controller)
    }

    enum ParseError: Error {
        case missingLanguage
        case missingTree
        case missingCursorNode
    }
}

@MainActor
final class MockJumpToDefinitionLSPClient: SuperEditorLSPClient {
    var definitionResult: Location?
    private(set) var definitionRequestCount = 0
    private(set) var lastDefinitionRequest: (line: Int, character: Int)?
    private(set) var openedFiles: [(uri: String, languageId: String, version: Int)] = []

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

    func openFile(uri: String, languageId: String, content: String, version: Int) async {
        openedFiles.append((uri, languageId, version))
    }

    func requestCompletion(line: Int, character: Int) async -> [CompletionItem] { [] }
    func requestCompletionDebounced(line: Int, character: Int) async -> [CompletionItem] { [] }
    func completionTriggerCharacters() -> Set<String> { [] }
    func requestHoverRaw(line: Int, character: Int) async -> Hover? { nil }
    func requestHoverRawDebounced(line: Int, character: Int) async -> Hover? { nil }

    func requestDefinition(line: Int, character: Int) async -> Location? {
        definitionRequestCount += 1
        lastDefinitionRequest = (line, character)
        return definitionResult
    }

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
}
#endif
