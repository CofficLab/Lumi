#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

@MainActor
final class EditorPanelControllerTests: XCTestCase {
    func testClearDataClearsHoverAndReferencesAndClosesReferencePanel() {
        let panelState = EditorPanelState()
        let controller = EditorPanelController(panelState: panelState)

        panelState.setMouseHover(content: "hover", symbolRect: .init(x: 1, y: 2, width: 3, height: 4))
        panelState.referenceResults = [
            EditorReferenceResult(
                url: URL(fileURLWithPath: "/tmp/demo.swift"),
                line: 3,
                column: 2,
                path: "demo.swift",
                preview: "let value = 1"
            )
        ]
        panelState.isReferencePanelPresented = true

        controller.clearData(closeReferences: false)

        XCTAssertNil(panelState.mouseHoverContent)
        XCTAssertEqual(panelState.mouseHoverSymbolRect, .zero)
        XCTAssertTrue(panelState.referenceResults.isEmpty)
        XCTAssertFalse(panelState.isReferencePanelPresented)
    }

    func testUpdateSelectedProblemDiagnosticMatchesCursorRange() {
        let panelState = EditorPanelState()
        let controller = EditorPanelController(panelState: panelState)
        let diagnostic = makeDiagnostic(
            startLine: 1,
            startCharacter: 2,
            endLine: 1,
            endCharacter: 5
        )
        panelState.problemDiagnostics = [diagnostic]

        controller.updateSelectedProblemDiagnostic(line: 2, column: 4)

        XCTAssertEqual(panelState.selectedProblemDiagnostic, diagnostic)
    }

    func testRestoreRehydratesSnapshotAndPayload() {
        let panelState = EditorPanelState()
        let controller = EditorPanelController(panelState: panelState)
        let diagnostic = makeDiagnostic(
            startLine: 0,
            startCharacter: 0,
            endLine: 0,
            endCharacter: 4
        )
        let sessionState = EditorPanelSessionState(
            mouseHoverContent: "hover",
            mouseHoverSymbolRect: .init(x: 10, y: 12, width: 30, height: 14),
            referenceResults: [
                ReferenceResult(
                    url: URL(fileURLWithPath: "/tmp/demo.swift"),
                    line: 4,
                    column: 2,
                    path: "demo.swift",
                    preview: "func demo()"
                )
            ],
            isOpenEditorsPanelPresented: true,
            isReferencePanelPresented: true,
            isWorkspaceSymbolSearchPresented: true,
            isCallHierarchyPresented: false,
            problemDiagnostics: [diagnostic],
            selectedProblemDiagnostic: diagnostic,
            isProblemsPanelPresented: true
        )

        controller.restore(from: sessionState)

        XCTAssertEqual(panelState.mouseHoverContent, "hover")
        XCTAssertEqual(panelState.referenceResults.count, 1)
        XCTAssertEqual(panelState.problemDiagnostics, [diagnostic])
        XCTAssertEqual(panelState.selectedProblemDiagnostic, diagnostic)
        XCTAssertTrue(panelState.isOpenEditorsPanelPresented)
        XCTAssertTrue(panelState.isReferencePanelPresented)
        XCTAssertTrue(panelState.isWorkspaceSymbolSearchPresented)
        XCTAssertTrue(panelState.isProblemsPanelPresented)
    }

    private func makeDiagnostic(
        startLine: Int,
        startCharacter: Int,
        endLine: Int,
        endCharacter: Int
    ) -> Diagnostic {
        Diagnostic(
            range: .init(
                start: .init(line: startLine, character: startCharacter),
                end: .init(line: endLine, character: endCharacter)
            ),
            severity: .warning,
            code: nil,
            codeDescription: nil,
            source: nil,
            message: "demo",
            tags: nil,
            relatedInformation: nil
        )
    }
}
#endif
