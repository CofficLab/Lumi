#if canImport(XCTest)
import CodeEditSourceEditor
import Foundation
import LanguageServerProtocol
import XCTest
@testable import EditorService

@MainActor
final class EditorJumpToDefinitionDelegateTests: XCTestCase {
    func testSubstringIfValidReturnsTextForValidRange() {
        let text = "let cafe = 1"
        let range = (text as NSString).range(of: "cafe")

        XCTAssertEqual(
            EditorJumpToDefinitionDelegate.substringIfValid(in: text, range: range),
            "cafe"
        )
    }

    func testSubstringIfValidRejectsStaleRanges() {
        let text = "let value = 1"

        XCTAssertNil(EditorJumpToDefinitionDelegate.substringIfValid(
            in: text,
            range: NSRange(location: -1, length: 3)
        ))
        XCTAssertNil(EditorJumpToDefinitionDelegate.substringIfValid(
            in: text,
            range: NSRange(location: (text as NSString).length + 1, length: 1)
        ))
        XCTAssertNil(EditorJumpToDefinitionDelegate.substringIfValid(
            in: text,
            range: NSRange(location: 4, length: (text as NSString).length)
        ))
    }

    func testLSPFileURLAcceptsUnescapedFileURL() {
        let url = EditorJumpToDefinitionDelegate.fileURL(fromLSPURI: "file:///tmp/project/My File.swift")

        XCTAssertEqual(url?.path, "/tmp/project/My File.swift")
    }

    func testSameFileComparisonNormalizesUnescapedLSPFileURL() {
        let currentURL = URL(fileURLWithPath: "/tmp/project/My File.swift")
        let targetURL = EditorJumpToDefinitionDelegate.fileURL(fromLSPURI: "file:///tmp/project/My File.swift")

        XCTAssertTrue(EditorJumpToDefinitionDelegate.isSameFile(
            currentFileURL: currentURL,
            targetURL: targetURL
        ))
    }

    @MainActor
    func testReferencePreviewLineReadsUTF16File() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorJumpToDefinitionDelegateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("Reference.swift")
        try """
        struct Reference {
            let localized = true
        }
        """.write(to: url, atomically: true, encoding: .utf16)

        let controller = EditorLSPActionController()

        XCTAssertEqual(controller.previewLine(from: url, at: 2), "let localized = true")
    }

    func testASTSearchFromRootFindsEarlierSwiftDefinition() throws {
        let source = JumpToDefinitionTestSupport.greetFixture
        let (_, root) = try JumpToDefinitionTestSupport.parseSwiftTree(for: source)
        let delegate = EditorJumpToDefinitionDelegate()
        let useRange = JumpToDefinitionTestSupport.symbolRange(in: source, symbol: "greet", occurrence: 1)

        let definitionRange = delegate.findDefinitionInTreeRoot(
            word: "greet",
            cursorRange: useRange,
            content: source,
            root: root
        )

        XCTAssertNotNil(definitionRange)
        XCTAssertLessThan(definitionRange!.location, useRange.location)
    }

    func testASTSearchFromRootFindsLaterSwiftDefinition() throws {
        let source = JumpToDefinitionTestSupport.laterDefinitionFixture
        let (_, root) = try JumpToDefinitionTestSupport.parseSwiftTree(for: source)
        let delegate = EditorJumpToDefinitionDelegate()
        let useRange = JumpToDefinitionTestSupport.symbolRange(in: source, symbol: "speak", occurrence: 0)

        let definitionRange = delegate.findDefinitionInTreeRoot(
            word: "speak",
            cursorRange: useRange,
            content: source,
            root: root
        )

        XCTAssertNotNil(definitionRange)
        XCTAssertGreaterThan(definitionRange!.location, useRange.location)
    }

    func testASTSearchFromCursorSubtreeMissesEarlierDefinition() throws {
        let source = JumpToDefinitionTestSupport.greetFixture
        let (tree, root) = try JumpToDefinitionTestSupport.parseSwiftTree(for: source)
        let delegate = EditorJumpToDefinitionDelegate()
        let useRange = JumpToDefinitionTestSupport.symbolRange(in: source, symbol: "greet", occurrence: 1)
        let cursorNode = try JumpToDefinitionTestSupport.cursorNode(
            in: tree,
            at: useRange.location,
            content: source
        )

        XCTAssertNil(delegate.findDefinitionInCursorSubtree(
            word: "greet",
            cursorRange: useRange,
            content: source,
            cursorNode: cursorNode
        ))
        XCTAssertNotNil(delegate.findDefinitionInTreeRoot(
            word: "greet",
            cursorRange: useRange,
            content: source,
            root: root
        ))
    }

    func testQueryLinksPrefersLSPResultOverLocalFallback() async {
        let source = JumpToDefinitionTestSupport.greetFixture
        let fileURL = URL(fileURLWithPath: "/tmp/JumpToDefinitionTests/TestFile.swift")
        let mockLSP = MockJumpToDefinitionLSPClient()
        let useRange = JumpToDefinitionTestSupport.symbolRange(in: source, symbol: "greet", occurrence: 1)
        mockLSP.definitionResult = Location(
            uri: fileURL.absoluteString,
            range: LSPRange(
                start: Position(line: 4, character: 4),
                end: Position(line: 4, character: 9)
            )
        )
        let (delegate, controller) = JumpToDefinitionTestSupport.makeDelegate(
            content: source,
            lspClient: mockLSP,
            fileURL: fileURL
        )

        let links = await delegate.queryLinks(forRange: useRange, textView: controller)

        XCTAssertEqual(mockLSP.definitionRequestCount, 1)
        XCTAssertEqual(links?.count, 1)
        XCTAssertNotEqual(
            links?.first?.targetRange.range.location,
            JumpToDefinitionTestSupport.symbolRange(in: source, symbol: "greet", occurrence: 0).location
        )
    }

    func testQueryLinksReturnsCrossFileLinkFromLSP() async {
        let source = "let value = greet()\n"
        let currentURL = URL(fileURLWithPath: "/tmp/JumpToDefinitionTests/Current.swift")
        let otherURL = URL(fileURLWithPath: "/tmp/JumpToDefinitionTests/Other.swift")
        let mockLSP = MockJumpToDefinitionLSPClient()
        mockLSP.definitionResult = Location(
            uri: otherURL.absoluteString,
            range: LSPRange(
                start: Position(line: 0, character: 5),
                end: Position(line: 0, character: 10)
            )
        )
        let (delegate, controller) = JumpToDefinitionTestSupport.makeDelegate(
            content: source,
            lspClient: mockLSP,
            fileURL: currentURL
        )
        let useRange = JumpToDefinitionTestSupport.symbolRange(in: source, symbol: "greet", occurrence: 0)

        let links = await delegate.queryLinks(forRange: useRange, textView: controller)

        XCTAssertEqual(links?.count, 1)
        XCTAssertEqual(links?.first?.url?.standardizedFileURL, otherURL.standardizedFileURL)
    }

    func testQueryLinksUsesRegexWhenTreeSitterUnavailableEvenInStructuredProject() async {
        let source = JumpToDefinitionTestSupport.regexFixture
        let mockLSP = MockJumpToDefinitionLSPClient()
        let (delegate, controller) = JumpToDefinitionTestSupport.makeDelegate(
            content: source,
            lspClient: mockLSP,
            structuredProject: true
        )
        let useRange = JumpToDefinitionTestSupport.symbolRange(in: source, symbol: "hello", occurrence: 1)

        let links = await delegate.queryLinks(forRange: useRange, textView: controller)

        XCTAssertEqual(links?.count, 1)
        XCTAssertNil(links?.first?.url)
        XCTAssertLessThan(links!.first!.targetRange.range.location, useRange.location)
    }

    func testQueryLinksUsesLspClientProviderWhenDirectClientMissing() async {
        let source = "let value = greet()\n"
        let mockLSP = MockJumpToDefinitionLSPClient()
        mockLSP.definitionResult = Location(
            uri: URL(fileURLWithPath: "/tmp/JumpToDefinitionTests/TestFile.swift").absoluteString,
            range: LSPRange(
                start: Position(line: 0, character: 12),
                end: Position(line: 0, character: 17)
            )
        )
        let (delegate, controller) = JumpToDefinitionTestSupport.makeDelegate(
            content: source,
            lspClient: nil,
            lspClientProvider: { mockLSP }
        )
        let useRange = JumpToDefinitionTestSupport.symbolRange(in: source, symbol: "greet", occurrence: 0)

        let links = await delegate.queryLinks(forRange: useRange, textView: controller)

        XCTAssertEqual(mockLSP.definitionRequestCount, 1)
        XCTAssertEqual(links?.count, 1)
    }

    func testQueryLinksReturnsNilWhenAllStrategiesMiss() async {
        let source = "let value = missingSymbol\n"
        let mockLSP = MockJumpToDefinitionLSPClient()
        let (delegate, controller) = JumpToDefinitionTestSupport.makeDelegate(
            content: source,
            lspClient: mockLSP
        )
        let useRange = JumpToDefinitionTestSupport.symbolRange(in: source, symbol: "missingSymbol", occurrence: 0)

        let links = await delegate.queryLinks(forRange: useRange, textView: controller)

        XCTAssertNil(links)
    }

    func testRefreshExtensionProvidersRebindsJumpDelegateLSPClient() {
        let registry = EditorExtensionRegistry()
        let state = EditorState(editorExtensions: registry)
        let jumpDelegate = EditorJumpToDefinitionDelegate()
        state.jumpDelegate = jumpDelegate

        let firstClient = MockJumpToDefinitionLSPClient()
        registry.registerSuperEditorLSPClient(firstClient)
        state.refreshExtensionProviders()

        XCTAssertTrue(state.lspClient === firstClient)
        XCTAssertTrue(jumpDelegate.lspClient === firstClient)

        let secondClient = MockJumpToDefinitionLSPClient()
        registry.registerSuperEditorLSPClient(secondClient)
        state.refreshExtensionProviders()

        XCTAssertTrue(state.lspClient === secondClient)
        XCTAssertTrue(jumpDelegate.lspClient === secondClient)
    }
}
#endif
