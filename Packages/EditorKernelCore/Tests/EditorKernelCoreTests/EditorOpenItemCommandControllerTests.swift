import Testing
import Foundation
import LanguageServerProtocol
@testable import EditorKernelCore

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
}
