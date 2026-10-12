import Testing
import Foundation
import LanguageServerProtocol
@testable import EditorKernel

@Suite("EditorOpenItemCommandController")
struct EditorOpenItemCommandControllerTests {
    @Test("workspace symbol command resolves navigation and closes symbol search")
    func resolveWorkspaceSymbolCommand() {
        let symbol = EditorWorkspaceSymbolTarget(
            uri: "file:///tmp/sample.swift",
            line: 9,
            character: 3
        )

        let resolved = EditorOpenItemCommandController.resolve(.workspaceSymbol(symbol))
        #expect(resolved != nil)
        #expect(resolved?.closeWorkspaceSymbolSearch == true)
        if case let .workspaceSymbol(url, target)? = resolved?.navigationRequest {
            #expect(url.path == "/tmp/sample.swift")
            #expect(target.start.line == 10)
            #expect(target.start.column == 4)
        } else {
            Issue.record("Expected workspace symbol navigation request")
        }
    }

    @Test("workspace symbol command accepts unescaped file URLs")
    func resolveWorkspaceSymbolCommandWithUnescapedFileURL() {
        let symbol = EditorWorkspaceSymbolTarget(
            uri: "file:///tmp/project/My File.swift",
            line: 2,
            character: 5
        )

        let resolved = EditorOpenItemCommandController.resolve(.workspaceSymbol(symbol))

        if case let .workspaceSymbol(url, target)? = resolved?.navigationRequest {
            #expect(url.path == "/tmp/project/My File.swift")
            #expect(target.start.line == 3)
            #expect(target.start.column == 6)
        } else {
            Issue.record("Expected workspace symbol navigation request")
        }
    }

    @Test("problem command keeps diagnostic and opens problems panel")
    func resolveProblemCommand() {
        let diagnostic = Diagnostic(
            range: .init(
                start: .init(line: 0, character: 1),
                end: .init(line: 0, character: 4)
            ),
            severity: .warning,
            code: nil,
            codeDescription: nil,
            source: nil,
            message: "warn",
            tags: nil,
            relatedInformation: nil
        )

        let resolved = EditorOpenItemCommandController.resolve(.problem(diagnostic))
        #expect(resolved?.selectedProblemDiagnostic == diagnostic)
        #expect(resolved?.presentBottomPanel == .problems)
        #expect(resolved?.cursorPositions.count == 1)
    }

    @Test("workspace symbol command with invalid URI resolves to nil")
    func resolveWorkspaceSymbolCommandWithInvalidURI() {
        let symbol = EditorWorkspaceSymbolTarget(
            uri: "not a valid uri://",
            line: 0,
            character: 0
        )

        #expect(EditorOpenItemCommandController.resolve(.workspaceSymbol(symbol)) == nil)
    }

    @Test("reference command resolves navigation and opens references panel")
    func resolveReferenceCommand() {
        let reference = ReferenceResult(
            url: URL(fileURLWithPath: "/tmp/a.swift"),
            line: 3,
            column: 5,
            path: "a.swift",
            preview: "let x = 1"
        )

        let resolved = EditorOpenItemCommandController.resolve(.reference(reference))

        #expect(resolved?.selectedReferenceResult == reference)
        #expect(resolved?.presentBottomPanel == .references)
        #expect(resolved?.navigationRequest == .reference(reference))
        #expect(resolved?.selectedProblemDiagnostic == nil)
    }

    @Test("call hierarchy command resolves navigation without bottom panel")
    func resolveCallHierarchyCommand() {
        let position = EditorCursorPosition(
            start: .init(line: 4, column: 2),
            end: nil
        )
        let url = URL(fileURLWithPath: "/tmp/b.swift")

        let resolved = EditorOpenItemCommandController.resolve(.callHierarchyItem(url, position))

        #expect(resolved?.navigationRequest == .callHierarchyItem(url, position))
        #expect(resolved?.presentBottomPanel == nil)
        #expect(resolved?.closeWorkspaceSymbolSearch == false)
    }

    @Test("document symbol command resolves cursor position only")
    func resolveDocumentSymbolCommand() {
        let symbol = DocumentSymbol(
            name: "myFunc",
            detail: nil,
            kind: .function,
            deprecated: nil,
            range: .init(
                start: .init(line: 7, character: 0),
                end: .init(line: 9, character: 20)
            ),
            selectionRange: .init(
                start: .init(line: 7, character: 6),
                end: .init(line: 7, character: 12)
            ),
            children: nil
        )
        let item = EditorDocumentSymbolItem(symbol: symbol)

        let resolved = EditorOpenItemCommandController.resolve(.documentSymbol(item))

        #expect(resolved?.cursorPositions.count == 1)
        #expect(resolved?.cursorPositions.first?.start.line == 8)
        #expect(resolved?.cursorPositions.first?.start.column == 7)
        #expect(resolved?.navigationRequest == nil)
        #expect(resolved?.presentBottomPanel == nil)
    }
}
