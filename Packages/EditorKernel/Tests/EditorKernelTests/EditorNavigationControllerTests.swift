import Testing
import Foundation
import LanguageServerProtocol
@testable import EditorKernel

@Suite("EditorNavigationController")
struct EditorNavigationControllerTests {
    @Test("reference request resolves to reference target")
    func resolveReferenceRequest() {
        let url = URL(fileURLWithPath: "/tmp/a.swift")
        let request = EditorNavigationRequest.reference(
            ReferenceResult(url: url, line: 3, column: 5, path: "a.swift", preview: "")
        )

        let resolved = EditorNavigationController.resolve(request)
        #expect(resolved.url == url)
        #expect(resolved.target.start.line == 3)
        #expect(resolved.target.start.column == 5)
        #expect(resolved.highlightLine == false)
    }

    @Test("diagnostic cursor position includes selection range")
    func cursorPositionsForDiagnostic() {
        let diagnostic = Diagnostic(
            range: .init(
                start: .init(line: 1, character: 2),
                end: .init(line: 1, character: 6)
            ),
            severity: .warning,
            code: nil,
            codeDescription: nil,
            source: nil,
            message: "msg",
            tags: nil,
            relatedInformation: nil
        )

        let positions = EditorNavigationController.cursorPositions(for: diagnostic)
        #expect(positions.count == 1)
        #expect(positions[0].start.line == 2)
        #expect(positions[0].start.column == 3)
        #expect(positions[0].end?.column == 7)
    }

    @Test("highlighted definition target expands to full line")
    func resolvedDefinitionTargetHighlightLine() {
        let target = EditorCursorPosition(start: .init(line: 2, column: 4), end: nil)
        let content = "one\ntwo three\nfour"

        let resolved = EditorNavigationController.resolvedDefinitionTarget(
            from: target,
            highlightLine: true,
            content: content
        )

        #expect(resolved.start.line == 2)
        #expect(resolved.start.column == 1)
        #expect(resolved.end?.line == 2)
        #expect(resolved.end?.column == 10)
    }
}
