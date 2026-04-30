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
        panelState.semanticProblems = [
            EditorSemanticProblem(
                reason: .init(
                    id: "build-context-resync",
                    severity: .warning,
                    title: "Build Context 需要同步",
                    message: "当前 build context 已失效。"
                )
            )
        ]
        panelState.isReferencePanelPresented = true

        controller.clearData(closeReferences: false)

        XCTAssertNil(panelState.mouseHoverContent)
        XCTAssertEqual(panelState.mouseHoverSymbolRect, .zero)
        XCTAssertTrue(panelState.referenceResults.isEmpty)
        XCTAssertEqual(panelState.semanticProblems.count, 1)
        XCTAssertFalse(panelState.isReferencePanelPresented)
    }

    func testClearDataWithDiagnosticsAlsoClearsSemanticProblems() {
        let panelState = EditorPanelState()
        let controller = EditorPanelController(panelState: panelState)
        panelState.problemDiagnostics = [makeDiagnostic(startLine: 0, startCharacter: 0, endLine: 0, endCharacter: 1)]
        panelState.semanticProblems = [
            EditorSemanticProblem(
                reason: .init(
                    id: "file-not-in-target",
                    severity: .error,
                    title: "文件未进 Target",
                    message: "demo.swift 不属于任何 target。"
                )
            )
        ]

        controller.clearData(clearDiagnostics: true)

        XCTAssertTrue(panelState.problemDiagnostics.isEmpty)
        XCTAssertTrue(panelState.semanticProblems.isEmpty)
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
            isOutlinePanelPresented: true,
            isReferencePanelPresented: true,
            isWorkspaceSearchPresented: true,
            isWorkspaceSymbolSearchPresented: true,
            isCallHierarchyPresented: false,
            problemDiagnostics: [diagnostic],
            semanticProblems: [
                EditorSemanticProblem(
                    reason: .init(
                        id: "multiple-targets-ambiguous",
                        severity: .warning,
                        title: "多 Target 歧义",
                        message: "当前文件属于多个 target。"
                    )
                )
            ],
            selectedProblemDiagnostic: diagnostic,
            isProblemsPanelPresented: true
        )

        controller.restore(from: sessionState)

        XCTAssertTrue(panelState.isOutlinePanelPresented)

        XCTAssertEqual(panelState.mouseHoverContent, "hover")
        XCTAssertEqual(panelState.referenceResults.count, 1)
        XCTAssertEqual(panelState.problemDiagnostics, [diagnostic])
        XCTAssertEqual(panelState.semanticProblems.count, 1)
        XCTAssertEqual(panelState.selectedProblemDiagnostic, diagnostic)
        XCTAssertTrue(panelState.isOpenEditorsPanelPresented)
        XCTAssertTrue(panelState.isReferencePanelPresented)
        XCTAssertTrue(panelState.isWorkspaceSearchPresented)
        XCTAssertTrue(panelState.isWorkspaceSymbolSearchPresented)
        XCTAssertTrue(panelState.isProblemsPanelPresented)
    }

    func testPresentBottomPanelSwitchesToExclusivePanelVisibility() {
        let panelState = EditorPanelState()
        let controller = EditorPanelController(panelState: panelState)

        controller.presentBottomPanel(.references)
        XCTAssertTrue(panelState.isReferencePanelPresented)
        XCTAssertFalse(panelState.isProblemsPanelPresented)
        XCTAssertFalse(panelState.isWorkspaceSearchPresented)
        XCTAssertEqual(panelState.activeBottomPanel, .references)

        controller.presentBottomPanel(.searchResults)
        XCTAssertFalse(panelState.isReferencePanelPresented)
        XCTAssertFalse(panelState.isProblemsPanelPresented)
        XCTAssertTrue(panelState.isWorkspaceSearchPresented)
        XCTAssertEqual(panelState.activeBottomPanel, .searchResults)

        controller.presentBottomPanel(.callHierarchy)
        XCTAssertFalse(panelState.isWorkspaceSearchPresented)
        XCTAssertTrue(panelState.isCallHierarchyPresented)
        XCTAssertEqual(panelState.activeBottomPanel, .callHierarchy)
    }

    func testPresentBottomPanelNilClosesAllBottomPanels() {
        let panelState = EditorPanelState()
        let controller = EditorPanelController(panelState: panelState)
        panelState.isProblemsPanelPresented = true
        panelState.isWorkspaceSymbolSearchPresented = true

        controller.presentBottomPanel(nil)

        XCTAssertFalse(panelState.isProblemsPanelPresented)
        XCTAssertFalse(panelState.isReferencePanelPresented)
        XCTAssertFalse(panelState.isWorkspaceSearchPresented)
        XCTAssertFalse(panelState.isWorkspaceSymbolSearchPresented)
        XCTAssertFalse(panelState.isCallHierarchyPresented)
        XCTAssertNil(panelState.activeBottomPanel)
    }

    func testWorkspaceSearchResultsRetainCollapsedFileStateForVisibleFiles() {
        let panelState = EditorPanelState()
        let controller = EditorPanelController(panelState: panelState)
        panelState.workspaceSearchCollapsedFilePaths = ["Sources/App.swift", "Sources/Old.swift"]

        controller.setWorkspaceSearchResults(
            [
                .init(
                    url: URL(fileURLWithPath: "/tmp/Sources/App.swift"),
                    path: "Sources/App.swift",
                    matches: [
                        .init(
                            url: URL(fileURLWithPath: "/tmp/Sources/App.swift"),
                            line: 4,
                            column: 3,
                            path: "Sources/App.swift",
                            preview: "target()"
                        )
                    ]
                ),
                .init(
                    url: URL(fileURLWithPath: "/tmp/Tests/AppTests.swift"),
                    path: "Tests/AppTests.swift",
                    matches: [
                        .init(
                            url: URL(fileURLWithPath: "/tmp/Tests/AppTests.swift"),
                            line: 9,
                            column: 2,
                            path: "Tests/AppTests.swift",
                            preview: "XCTAssert(target)"
                        )
                    ]
                )
            ],
            summary: .init(query: "target", totalMatches: 2, totalFiles: 2),
            errorMessage: nil
        )

        XCTAssertEqual(panelState.workspaceSearchCollapsedFilePaths, ["Sources/App.swift"])
    }

    func testWorkspaceSearchResultsClearSelectedMatchWhenNoLongerVisible() {
        let panelState = EditorPanelState()
        let controller = EditorPanelController(panelState: panelState)
        panelState.selectedWorkspaceSearchMatchID = "Sources/App.swift:4:3:target()"

        controller.setWorkspaceSearchResults(
            [
                .init(
                    url: URL(fileURLWithPath: "/tmp/Tests/AppTests.swift"),
                    path: "Tests/AppTests.swift",
                    matches: [
                        .init(
                            url: URL(fileURLWithPath: "/tmp/Tests/AppTests.swift"),
                            line: 9,
                            column: 2,
                            path: "Tests/AppTests.swift",
                            preview: "XCTAssert(target)"
                        )
                    ]
                )
            ],
            summary: .init(query: "target", totalMatches: 1, totalFiles: 1),
            errorMessage: nil
        )

        XCTAssertNil(panelState.selectedWorkspaceSearchMatchID)
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
