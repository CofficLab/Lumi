#if canImport(XCTest)
import XCTest
import CodeEditSourceEditor
@testable import Lumi

@MainActor
final class EditorSessionTests: XCTestCase {
    func testInitStoresSessionState() {
        let fileURL = URL(fileURLWithPath: "/tmp/demo.swift")
        let session = EditorSession(
            fileURL: fileURL,
            multiCursorState: MultiCursorState(
                primary: .init(location: 2, length: 0),
                secondary: [.init(location: 10, length: 3)]
            ),
            panelState: .init(
                mouseHoverContent: "hover",
                mouseHoverSymbolRect: CGRect(x: 1, y: 2, width: 3, height: 4),
                referenceResults: [
                    .init(url: fileURL, line: 1, column: 1, path: "demo.swift", preview: "let a = 1")
                ],
                isReferencePanelPresented: true,
                problemDiagnostics: [],
                selectedProblemDiagnostic: nil,
                isProblemsPanelPresented: true
            ),
            isDirty: true,
            findReplaceState: .init(findText: "needle", replaceText: "replacement", isFindPanelVisible: true),
            scrollState: .init(viewportOrigin: CGPoint(x: 12, y: 48)),
            viewState: .init(
                primaryCursorLine: 4,
                primaryCursorColumn: 8,
                cursorPositions: [
                    CursorPosition(
                        start: .init(line: 4, column: 8),
                        end: nil
                    )
                ]
            )
        )

        XCTAssertEqual(session.fileURL, fileURL)
        XCTAssertEqual(session.multiCursorState.all.count, 2)
        XCTAssertEqual(session.mouseHoverContent, "hover")
        XCTAssertEqual(session.referenceResults.count, 1)
        XCTAssertTrue(session.isReferencePanelPresented)
        XCTAssertTrue(session.isProblemsPanelPresented)
        XCTAssertTrue(session.isDirty)
        XCTAssertEqual(session.findReplaceState.findText, "needle")
        XCTAssertEqual(session.findReplaceState.replaceText, "replacement")
        XCTAssertTrue(session.findReplaceState.isFindPanelVisible)
        XCTAssertEqual(session.scrollState.viewportOrigin, CGPoint(x: 12, y: 48))
        XCTAssertEqual(session.viewState.primaryCursorLine, 4)
        XCTAssertEqual(session.viewState.primaryCursorColumn, 8)
        XCTAssertEqual(session.viewState.cursorPositions.count, 1)
        XCTAssertEqual(session.viewState.cursorPositions.first?.start.line, 4)
        XCTAssertEqual(session.viewState.cursorPositions.first?.start.column, 8)
    }

    func testResetClearsSessionState() {
        let fileURL = URL(fileURLWithPath: "/tmp/demo.swift")
        let session = EditorSession(fileURL: fileURL)

        session.reset()

        XCTAssertNil(session.fileURL)
        XCTAssertEqual(session.multiCursorState.all.count, 1)
        XCTAssertNil(session.mouseHoverContent)
        XCTAssertTrue(session.referenceResults.isEmpty)
        XCTAssertFalse(session.isReferencePanelPresented)
        XCTAssertTrue(session.problemDiagnostics.isEmpty)
        XCTAssertFalse(session.isProblemsPanelPresented)
        XCTAssertFalse(session.isDirty)
        XCTAssertEqual(session.findReplaceState, EditorFindReplaceState())
        XCTAssertEqual(session.scrollState, EditorScrollState())
        XCTAssertEqual(session.viewState.primaryCursorLine, 1)
        XCTAssertEqual(session.viewState.primaryCursorColumn, 1)
        XCTAssertTrue(session.viewState.cursorPositions.isEmpty)
    }

    func testSnapshotRoundTripPreservesSessionLocalState() {
        let fileURL = URL(fileURLWithPath: "/tmp/demo.swift")
        let original = EditorSession(
            fileURL: fileURL,
            multiCursorState: MultiCursorState(
                primary: .init(location: 1, length: 0),
                secondary: [.init(location: 9, length: 2)]
            ),
            panelState: .init(mouseHoverContent: "hover", isReferencePanelPresented: true),
            isDirty: true,
            findReplaceState: .init(findText: "abc", replaceText: "xyz", isFindPanelVisible: true),
            scrollState: .init(viewportOrigin: CGPoint(x: 20, y: 80)),
            viewState: .init(
                primaryCursorLine: 7,
                primaryCursorColumn: 3,
                cursorPositions: [
                    CursorPosition(start: .init(line: 7, column: 3), end: nil)
                ]
            )
        )

        let copied = EditorSession(snapshot: original)

        XCTAssertEqual(copied.fileURL, fileURL)
        XCTAssertEqual(copied.multiCursorState.all.count, 2)
        XCTAssertEqual(copied.mouseHoverContent, "hover")
        XCTAssertTrue(copied.isReferencePanelPresented)
        XCTAssertTrue(copied.isDirty)
        XCTAssertEqual(copied.findReplaceState.findText, "abc")
        XCTAssertEqual(copied.findReplaceState.replaceText, "xyz")
        XCTAssertEqual(copied.scrollState.viewportOrigin, CGPoint(x: 20, y: 80))
        XCTAssertEqual(copied.viewState.primaryCursorLine, 7)
        XCTAssertEqual(copied.viewState.primaryCursorColumn, 3)
        XCTAssertEqual(copied.viewState.cursorPositions.first?.start.line, 7)
        XCTAssertEqual(copied.viewState.cursorPositions.first?.start.column, 3)
    }

    func testEditorSessionPanelStateRoundTrip() {
        let session = EditorSession()
        let diagnostic = Diagnostic(
            range: .init(
                start: .init(line: 0, character: 1),
                end: .init(line: 0, character: 3)
            ),
            severity: .warning,
            code: nil,
            codeDescription: nil,
            source: nil,
            message: "warn",
            relatedInformation: nil,
            tags: nil,
            data: nil
        )

        session.panelState = .init(
            mouseHoverContent: "hover",
            mouseHoverSymbolRect: CGRect(x: 2, y: 4, width: 6, height: 8),
            referenceResults: [
                .init(url: URL(fileURLWithPath: "/tmp/demo.swift"), line: 2, column: 4, path: "demo.swift", preview: "let demo = 1")
            ],
            isReferencePanelPresented: true,
            isWorkspaceSymbolSearchPresented: true,
            isCallHierarchyPresented: true,
            problemDiagnostics: [diagnostic],
            selectedProblemDiagnostic: diagnostic,
            isProblemsPanelPresented: true
        )

        let restored = session.panelState

        XCTAssertEqual(restored.mouseHoverContent, "hover")
        XCTAssertEqual(restored.referenceResults.count, 1)
        XCTAssertEqual(restored.problemDiagnostics, [diagnostic])
        XCTAssertEqual(restored.selectedProblemDiagnostic, diagnostic)
        XCTAssertTrue(restored.isReferencePanelPresented)
        XCTAssertTrue(restored.isWorkspaceSymbolSearchPresented)
        XCTAssertTrue(restored.isCallHierarchyPresented)
        XCTAssertTrue(restored.isProblemsPanelPresented)
        XCTAssertEqual(session.panelSnapshot, restored.snapshot)
    }

    func testEditorViewStateDefaultsToPrimaryCursorOrigin() {
        let state = EditorViewState()

        XCTAssertEqual(state.primaryCursorLine, 1)
        XCTAssertEqual(state.primaryCursorColumn, 1)
        XCTAssertTrue(state.cursorPositions.isEmpty)
    }

    func testViewStateControllerBuildsPrimaryCursorFromPositions() {
        let viewState = EditorViewStateController.state(
            from: [
                CursorPosition(start: .init(line: 6, column: 9), end: nil)
            ]
        )

        XCTAssertEqual(viewState.primaryCursorLine, 6)
        XCTAssertEqual(viewState.primaryCursorColumn, 9)
        XCTAssertEqual(viewState.cursorPositions.count, 1)
    }

    func testViewStateControllerBuildsCursorPositionsFromSelections() {
        let text = "alpha\nbeta\ngamma"
        let selection = MultiCursorSelection(location: 6, length: 4)

        let viewState = EditorViewStateController.positions(
            from: [selection],
            text: text,
            fallbackLine: 1,
            fallbackColumn: 1
        ) { offset, text in
            var consumed = 0
            var line = 0
            var character = 0
            for unit in text.utf16 {
                if consumed == offset { break }
                if unit == 0x0A {
                    line += 1
                    character = 0
                } else {
                    character += 1
                }
                consumed += 1
            }
            return Position(line: line, character: character)
        }

        XCTAssertEqual(viewState.primaryCursorLine, 2)
        XCTAssertEqual(viewState.primaryCursorColumn, 1)
        XCTAssertEqual(viewState.cursorPositions.count, 1)
        XCTAssertEqual(viewState.cursorPositions.first?.start.line, 2)
        XCTAssertEqual(viewState.cursorPositions.first?.start.column, 1)
        XCTAssertEqual(viewState.cursorPositions.first?.end?.line, 2)
        XCTAssertEqual(viewState.cursorPositions.first?.end?.column, 5)
    }

    func testViewStateControllerRespectsFallbackWhenSelectionsCannotResolve() {
        let viewState = EditorViewStateController.positions(
            from: [.init(location: 999, length: 3)],
            text: "short",
            fallbackLine: 4,
            fallbackColumn: 7
        ) { _, _ in
            nil
        }

        XCTAssertEqual(viewState.primaryCursorLine, 4)
        XCTAssertEqual(viewState.primaryCursorColumn, 7)
        XCTAssertEqual(viewState.cursorPositions.first?.start.line, 4)
        XCTAssertEqual(viewState.cursorPositions.first?.start.column, 7)
        XCTAssertEqual(viewState.cursorPositions.first?.end?.column, 10)
    }

    func testFindReplaceStateControllerBuildsState() {
        let state = EditorFindReplaceStateController.state(
            findText: "find",
            replaceText: "replace",
            isFindPanelVisible: true
        )

        XCTAssertEqual(state.findText, "find")
        XCTAssertEqual(state.replaceText, "replace")
        XCTAssertTrue(state.isFindPanelVisible)
    }

    func testFindReplaceStateControllerAppliesToSourceEditorState() {
        var sourceState = SourceEditorState()

        EditorFindReplaceStateController.apply(
            .init(findText: "needle", replaceText: "value", isFindPanelVisible: true),
            to: &sourceState
        )

        XCTAssertEqual(sourceState.findText, "needle")
        XCTAssertEqual(sourceState.replaceText, "value")
        XCTAssertTrue(sourceState.findPanelVisible)
    }

    func testSourceEditorBindingControllerIgnoresCursorPositionsInMultiCursorMode() {
        var sourceState = SourceEditorState()
        sourceState.cursorPositions = [
            CursorPosition(start: .init(line: 4, column: 2), end: nil)
        ]
        sourceState.findText = "foo"
        sourceState.replaceText = "bar"
        sourceState.findPanelVisible = true

        let update = EditorSourceEditorBindingController.update(
            from: sourceState,
            multiCursorSelectionCount: 2
        )

        XCTAssertNil(update.viewState)
        XCTAssertEqual(update.findReplaceState.findText, "foo")
        XCTAssertEqual(update.findReplaceState.replaceText, "bar")
        XCTAssertTrue(update.findReplaceState.isFindPanelVisible)
    }

    func testSourceEditorBindingControllerBuildsViewStateInSingleCursorMode() {
        var sourceState = SourceEditorState()
        sourceState.cursorPositions = [
            CursorPosition(start: .init(line: 6, column: 3), end: nil)
        ]

        let update = EditorSourceEditorBindingController.update(
            from: sourceState,
            multiCursorSelectionCount: 1
        )

        XCTAssertEqual(update.viewState?.primaryCursorLine, 6)
        XCTAssertEqual(update.viewState?.primaryCursorColumn, 3)
        XCTAssertEqual(update.viewState?.cursorPositions.count, 1)
    }

    func testInteractionUpdateControllerResolvesFindReplaceUsingCurrentViewState() {
        let resolved = EditorInteractionUpdateController.resolve(
            .findReplace(.init(findText: "foo", replaceText: "bar", isFindPanelVisible: true)),
            currentViewState: .init(
                primaryCursorLine: 8,
                primaryCursorColumn: 4,
                cursorPositions: [
                    CursorPosition(start: .init(line: 8, column: 4), end: nil)
                ]
            )
        )

        XCTAssertEqual(resolved.bridgeState?.viewState.primaryCursorLine, 8)
        XCTAssertEqual(resolved.bridgeState?.viewState.primaryCursorColumn, 4)
        XCTAssertEqual(resolved.bridgeState?.findReplaceState?.findText, "foo")
        XCTAssertEqual(resolved.bridgeState?.findReplaceState?.replaceText, "bar")
        XCTAssertTrue(resolved.bridgeState?.findReplaceState?.isFindPanelVisible == true)
        XCTAssertNil(resolved.scrollState)
    }

    func testInteractionUpdateControllerPreservesCurrentViewStateForFindReplaceObservation() {
        let currentViewState = EditorViewState(
            primaryCursorLine: 18,
            primaryCursorColumn: 12,
            cursorPositions: [
                CursorPosition(start: .init(line: 18, column: 12), end: nil)
            ]
        )

        let resolved = EditorInteractionUpdateController.resolve(
            .findReplace(.init(findText: "abc", replaceText: "xyz", isFindPanelVisible: false)),
            currentViewState: currentViewState
        )

        XCTAssertEqual(resolved.bridgeState?.viewState, currentViewState)
        XCTAssertEqual(resolved.bridgeState?.findReplaceState?.findText, "abc")
        XCTAssertEqual(resolved.bridgeState?.findReplaceState?.replaceText, "xyz")
        XCTAssertFalse(resolved.bridgeState?.findReplaceState?.isFindPanelVisible ?? true)
    }

    func testInteractionUpdateControllerResolvesScrollWithoutBridgeState() {
        let resolved = EditorInteractionUpdateController.resolve(
            .scroll(.init(viewportOrigin: CGPoint(x: 10, y: 20))),
            currentViewState: .initial
        )

        XCTAssertNil(resolved.bridgeState)
        XCTAssertEqual(resolved.scrollState?.viewportOrigin, CGPoint(x: 10, y: 20))
    }

    func testInteractionUpdateControllerResolvesExplicitCursor() {
        let resolved = EditorInteractionUpdateController.resolve(
            .explicitCursor(
                [
                    CursorPosition(start: .init(line: 15, column: 7), end: nil)
                ],
                fallbackLine: 1,
                fallbackColumn: 1
            ),
            currentViewState: .initial
        )

        XCTAssertEqual(resolved.bridgeState?.viewState.primaryCursorLine, 15)
        XCTAssertEqual(resolved.bridgeState?.viewState.primaryCursorColumn, 7)
        XCTAssertEqual(resolved.bridgeState?.viewState.cursorPositions.count, 1)
        XCTAssertNil(resolved.scrollState)
    }

    func testInteractionUpdateControllerResolvesObservedCursorCommand() {
        let resolved = EditorInteractionUpdateController.resolve(
            .cursor(.observedPositions([], fallbackLine: 13, fallbackColumn: 2)),
            currentViewState: .initial
        )

        XCTAssertEqual(resolved.bridgeState?.viewState.primaryCursorLine, 13)
        XCTAssertEqual(resolved.bridgeState?.viewState.primaryCursorColumn, 2)
        XCTAssertTrue(resolved.bridgeState?.viewState.cursorPositions.isEmpty == true)
        XCTAssertNil(resolved.scrollState)
    }

    func testInteractionUpdateControllerResolvesPrimaryCursorCommand() {
        let resolved = EditorInteractionUpdateController.resolve(
            .cursor(
                .primary(
                    line: 20,
                    column: 11,
                    existingPositions: [
                        CursorPosition(start: .init(line: 1, column: 1), end: nil)
                    ],
                    preserveCursorSelection: true
                )
            ),
            currentViewState: .initial
        )

        XCTAssertEqual(resolved.bridgeState?.viewState.primaryCursorLine, 20)
        XCTAssertEqual(resolved.bridgeState?.viewState.primaryCursorColumn, 11)
        XCTAssertEqual(resolved.bridgeState?.viewState.cursorPositions.first?.start.line, 20)
        XCTAssertEqual(resolved.bridgeState?.viewState.cursorPositions.first?.start.column, 11)
    }

    func testInteractionUpdateControllerResolvesExplicitCursorWithFallbackWhenEmpty() {
        let resolved = EditorInteractionUpdateController.resolve(
            .explicitCursor([], fallbackLine: 5, fallbackColumn: 9),
            currentViewState: .initial
        )

        XCTAssertEqual(resolved.bridgeState?.viewState.primaryCursorLine, 5)
        XCTAssertEqual(resolved.bridgeState?.viewState.primaryCursorColumn, 9)
        XCTAssertTrue(resolved.bridgeState?.viewState.cursorPositions.isEmpty == true)
    }

    func testInteractionUpdateControllerResolvesSessionRestore() {
        let resolved = EditorInteractionUpdateController.resolve(
            .sessionRestore(
                .init(
                    cursorLine: 9,
                    cursorColumn: 3,
                    findReplaceState: .init(findText: "needle", replaceText: "value", isFindPanelVisible: true),
                    scrollState: .init(viewportOrigin: CGPoint(x: 4, y: 6)),
                    cursorPositions: []
                )
            ),
            currentViewState: .initial
        )

        XCTAssertEqual(resolved.bridgeState?.viewState.primaryCursorLine, 9)
        XCTAssertEqual(resolved.bridgeState?.viewState.primaryCursorColumn, 3)
        XCTAssertEqual(resolved.bridgeState?.findReplaceState?.findText, "needle")
        XCTAssertEqual(resolved.bridgeState?.findReplaceState?.replaceText, "value")
        XCTAssertEqual(resolved.scrollState?.viewportOrigin, CGPoint(x: 4, y: 6))
    }

    func testInteractionUpdateControllerResolvesBindingWithFallbackViewState() {
        let bindingUpdate = EditorSourceEditorBindingUpdate(
            viewState: nil,
            findReplaceState: .init(findText: "needle", replaceText: "value", isFindPanelVisible: true)
        )

        let resolved = EditorInteractionUpdateController.resolve(
            .sourceEditorBinding(bindingUpdate),
            currentViewState: .init(
                primaryCursorLine: 12,
                primaryCursorColumn: 6,
                cursorPositions: [
                    CursorPosition(start: .init(line: 12, column: 6), end: nil)
                ]
            )
        )

        XCTAssertEqual(resolved.bridgeState?.viewState.primaryCursorLine, 12)
        XCTAssertEqual(resolved.bridgeState?.viewState.primaryCursorColumn, 6)
        XCTAssertEqual(resolved.bridgeState?.findReplaceState?.findText, "needle")
        XCTAssertEqual(resolved.bridgeState?.findReplaceState?.replaceText, "value")
        XCTAssertTrue(resolved.bridgeState?.findReplaceState?.isFindPanelVisible == true)
    }

    func testNavigationControllerBuildsCursorPositionsForDiagnostic() {
        let diagnostic = Diagnostic(
            range: .init(
                start: .init(line: 2, character: 4),
                end: .init(line: 2, character: 9)
            ),
            severity: .warning,
            code: nil,
            codeDescription: nil,
            source: nil,
            message: "warning",
            relatedInformation: nil,
            tags: nil,
            data: nil
        )

        let positions = EditorNavigationController.cursorPositions(for: diagnostic)

        XCTAssertEqual(positions.count, 1)
        XCTAssertEqual(positions.first?.start.line, 3)
        XCTAssertEqual(positions.first?.start.column, 5)
        XCTAssertEqual(positions.first?.end?.line, 3)
        XCTAssertEqual(positions.first?.end?.column, 10)
    }

    func testNavigationControllerResolvesDefinitionTargetForLineHighlight() {
        let target = CursorPosition(
            start: .init(line: 2, column: 5),
            end: nil
        )

        let resolved = EditorNavigationController.resolvedDefinitionTarget(
            from: target,
            highlightLine: true,
            content: "alpha\nbeta\n"
        )

        XCTAssertEqual(resolved.start.line, 2)
        XCTAssertEqual(resolved.start.column, 1)
        XCTAssertEqual(resolved.end?.line, 2)
        XCTAssertEqual(resolved.end?.column, 5)
    }

    func testNavigationControllerResolvesReferenceRequest() {
        let reference = ReferenceResult(
            url: URL(fileURLWithPath: "/tmp/demo.swift"),
            line: 7,
            column: 3,
            path: "demo.swift",
            preview: "let value = 1"
        )

        let resolved = EditorNavigationController.resolve(.reference(reference))

        XCTAssertEqual(resolved.url, reference.url)
        XCTAssertEqual(resolved.target.start.line, 7)
        XCTAssertEqual(resolved.target.start.column, 3)
        XCTAssertFalse(resolved.highlightLine)
    }

    func testNavigationControllerResolvesDefinitionRequest() {
        let url = URL(fileURLWithPath: "/tmp/demo.swift")
        let target = CursorPosition(start: .init(line: 4, column: 2), end: nil)

        let resolved = EditorNavigationController.resolve(
            .definition(url, target, highlightLine: true)
        )

        XCTAssertEqual(resolved.url, url)
        XCTAssertEqual(resolved.target, target)
        XCTAssertTrue(resolved.highlightLine)
    }

    func testOpenItemCommandControllerResolvesReferenceCommand() {
        let reference = ReferenceResult(
            url: URL(fileURLWithPath: "/tmp/demo.swift"),
            line: 3,
            column: 9,
            path: "demo.swift",
            preview: "let value = 1"
        )

        let resolved = EditorOpenItemCommandController.resolve(.reference(reference))

        XCTAssertEqual(resolved?.navigationRequest, .reference(reference))
        XCTAssertNil(resolved?.selectedProblemDiagnostic)
        XCTAssertFalse(resolved?.closeWorkspaceSymbolSearch ?? true)
    }

    func testOpenItemCommandControllerResolvesProblemCommand() {
        let diagnostic = Diagnostic(
            range: .init(
                start: .init(line: 1, character: 2),
                end: .init(line: 1, character: 5)
            ),
            severity: .error,
            code: nil,
            codeDescription: nil,
            source: nil,
            message: "error",
            relatedInformation: nil,
            tags: nil,
            data: nil
        )

        let resolved = EditorOpenItemCommandController.resolve(.problem(diagnostic))

        XCTAssertEqual(resolved?.selectedProblemDiagnostic, diagnostic)
        XCTAssertEqual(resolved?.cursorPositions.count, 1)
        XCTAssertEqual(resolved?.cursorPositions.first?.start.line, 2)
        XCTAssertEqual(resolved?.cursorPositions.first?.start.column, 3)
        XCTAssertNil(resolved?.navigationRequest)
    }

    func testOpenItemCommandControllerResolvesWorkspaceSymbolCommand() {
        let item = WorkspaceSymbolItem(
            name: "Demo",
            kind: .class,
            tags: nil,
            containerName: nil,
            location: .init(
                uri: URL(fileURLWithPath: "/tmp/demo.swift").absoluteString,
                range: .init(
                    start: .init(line: 5, character: 2),
                    end: .init(line: 5, character: 6)
                )
            )
        )

        let resolved = EditorOpenItemCommandController.resolve(.workspaceSymbol(item))

        XCTAssertTrue(resolved?.closeWorkspaceSymbolSearch == true)
        if case let .workspaceSymbol(url, target)? = resolved?.navigationRequest {
            XCTAssertEqual(url, URL(fileURLWithPath: "/tmp/demo.swift"))
            XCTAssertEqual(target.start.line, 6)
            XCTAssertEqual(target.start.column, 3)
        } else {
            XCTFail("Expected workspace symbol navigation request")
        }
    }

    func testPanelCommandControllerTogglesProblemsAndClosesReferences() {
        let snapshot = EditorPanelSnapshot(
            isProblemsPanelPresented: false,
            isReferencePanelPresented: true,
            isWorkspaceSymbolSearchPresented: false,
            isCallHierarchyPresented: false
        )

        let updated = EditorPanelCommandController.apply(.toggleProblems, to: snapshot)

        XCTAssertTrue(updated.isProblemsPanelPresented)
        XCTAssertFalse(updated.isReferencePanelPresented)
    }

    func testPanelCommandControllerOpensAndClosesWorkspaceSymbolSearch() {
        let snapshot = EditorPanelSnapshot(
            isProblemsPanelPresented: false,
            isReferencePanelPresented: false,
            isWorkspaceSymbolSearchPresented: false,
            isCallHierarchyPresented: true
        )

        let opened = EditorPanelCommandController.apply(.openWorkspaceSymbolSearch, to: snapshot)
        let closed = EditorPanelCommandController.apply(.closeWorkspaceSymbolSearch, to: opened)

        XCTAssertTrue(opened.isWorkspaceSymbolSearchPresented)
        XCTAssertTrue(opened.isCallHierarchyPresented)
        XCTAssertFalse(closed.isWorkspaceSymbolSearchPresented)
    }

    func testPanelCommandControllerOpensAndClosesCallHierarchy() {
        let snapshot = EditorPanelSnapshot(
            isProblemsPanelPresented: false,
            isReferencePanelPresented: false,
            isWorkspaceSymbolSearchPresented: true,
            isCallHierarchyPresented: false
        )

        let opened = EditorPanelCommandController.apply(.openCallHierarchy, to: snapshot)
        let closed = EditorPanelCommandController.apply(.closeCallHierarchy, to: opened)

        XCTAssertTrue(opened.isCallHierarchyPresented)
        XCTAssertTrue(opened.isWorkspaceSymbolSearchPresented)
        XCTAssertFalse(closed.isCallHierarchyPresented)
    }

    func testBridgeStateControllerBuildsCombinedBridgeState() {
        let bridgeState = EditorBridgeStateController.state(
            cursorPositions: [
                CursorPosition(start: .init(line: 9, column: 4), end: nil)
            ],
            findReplaceState: .init(findText: "a", replaceText: "b", isFindPanelVisible: true)
        )

        XCTAssertEqual(bridgeState.viewState.primaryCursorLine, 9)
        XCTAssertEqual(bridgeState.viewState.primaryCursorColumn, 4)
        XCTAssertEqual(bridgeState.viewState.cursorPositions.count, 1)
        XCTAssertEqual(bridgeState.findReplaceState?.findText, "a")
        XCTAssertEqual(bridgeState.findReplaceState?.replaceText, "b")
        XCTAssertTrue(bridgeState.findReplaceState?.isFindPanelVisible == true)
    }

    func testBridgeStateControllerBuildsStateFromObservedCursorUpdate() {
        let bridgeState = EditorBridgeStateController.state(
            for: .observedPositions(
                [],
                fallbackLine: 7,
                fallbackColumn: 8
            )
        )

        XCTAssertEqual(bridgeState.viewState.primaryCursorLine, 7)
        XCTAssertEqual(bridgeState.viewState.primaryCursorColumn, 8)
        XCTAssertTrue(bridgeState.viewState.cursorPositions.isEmpty)
    }

    func testBridgeStateControllerBuildsStateFromPrimaryCursorUpdate() {
        let bridgeState = EditorBridgeStateController.state(
            for: .primary(
                line: 10,
                column: 6,
                existingPositions: [
                    CursorPosition(
                        start: .init(line: 2, column: 3),
                        end: .init(line: 2, column: 5)
                    )
                ],
                preserveCursorSelection: true
            )
        )

        XCTAssertEqual(bridgeState.viewState.primaryCursorLine, 10)
        XCTAssertEqual(bridgeState.viewState.primaryCursorColumn, 6)
        XCTAssertEqual(bridgeState.viewState.cursorPositions.first?.start.line, 10)
        XCTAssertEqual(bridgeState.viewState.cursorPositions.first?.start.column, 6)
        XCTAssertEqual(bridgeState.viewState.cursorPositions.first?.end?.line, 2)
        XCTAssertEqual(bridgeState.viewState.cursorPositions.first?.end?.column, 5)
    }

    func testBridgeStateControllerBuildsRestoreBridgeState() {
        let bridgeState = EditorBridgeStateController.state(
            from: EditorSessionRestoreResult(
                cursorLine: 5,
                cursorColumn: 7,
                findReplaceState: .init(findText: "needle", replaceText: "value", isFindPanelVisible: true),
                scrollState: .init(viewportOrigin: CGPoint(x: 2, y: 3)),
                cursorPositions: []
            )
        )

        XCTAssertEqual(bridgeState.viewState.primaryCursorLine, 5)
        XCTAssertEqual(bridgeState.viewState.primaryCursorColumn, 7)
        XCTAssertEqual(bridgeState.viewState.cursorPositions.count, 1)
        XCTAssertEqual(bridgeState.viewState.cursorPositions.first?.start.line, 5)
        XCTAssertEqual(bridgeState.viewState.cursorPositions.first?.start.column, 7)
        XCTAssertEqual(bridgeState.findReplaceState?.findText, "needle")
        XCTAssertEqual(bridgeState.findReplaceState?.replaceText, "value")
        XCTAssertTrue(bridgeState.findReplaceState?.isFindPanelVisible == true)
    }

    func testBridgeStateControllerBuildsLiveEditorBridgeState() {
        var sourceState = SourceEditorState()
        sourceState.cursorPositions = [
            CursorPosition(start: .init(line: 11, column: 6), end: nil)
        ]
        sourceState.findText = "find"
        sourceState.replaceText = "replace"
        sourceState.findPanelVisible = true

        let bridgeState = EditorBridgeStateController.state(
            from: sourceState,
            cursorLine: 3,
            cursorColumn: 2
        )

        XCTAssertEqual(bridgeState.viewState.primaryCursorLine, 11)
        XCTAssertEqual(bridgeState.viewState.primaryCursorColumn, 6)
        XCTAssertEqual(bridgeState.viewState.cursorPositions.count, 1)
        XCTAssertEqual(bridgeState.findReplaceState?.findText, "find")
        XCTAssertEqual(bridgeState.findReplaceState?.replaceText, "replace")
        XCTAssertTrue(bridgeState.findReplaceState?.isFindPanelVisible == true)
    }

    func testSessionSnapshotBuilderAcceptsBridgeState() {
        let sessionID = UUID()
        let snapshot = EditorSessionSnapshotBuilder.snapshot(
            preserving: sessionID,
            fileURL: URL(fileURLWithPath: "/tmp/demo.swift"),
            multiCursorState: MultiCursorState(
                primary: .init(location: 0, length: 0),
                secondary: [.init(location: 4, length: 2)]
            ),
            panelState: .init(
                mouseHoverContent: "hover",
                mouseHoverSymbolRect: .init(x: 1, y: 2, width: 3, height: 4),
                referenceResults: [],
                isReferencePanelPresented: true,
                isWorkspaceSymbolSearchPresented: true,
                isCallHierarchyPresented: true,
                problemDiagnostics: [],
                selectedProblemDiagnostic: nil,
                isProblemsPanelPresented: false
            ),
            isDirty: true,
            bridgeState: EditorBridgeState(
                viewState: .init(
                    primaryCursorLine: 8,
                    primaryCursorColumn: 9,
                    cursorPositions: [
                        CursorPosition(start: .init(line: 8, column: 9), end: nil)
                    ]
                ),
                findReplaceState: .init(findText: "needle", replaceText: "value", isFindPanelVisible: true)
            ),
            scrollState: .init(viewportOrigin: CGPoint(x: 7, y: 11))
        )

        XCTAssertEqual(snapshot.id, sessionID)
        XCTAssertEqual(snapshot.viewState.primaryCursorLine, 8)
        XCTAssertEqual(snapshot.viewState.primaryCursorColumn, 9)
        XCTAssertEqual(snapshot.findReplaceState.findText, "needle")
        XCTAssertEqual(snapshot.findReplaceState.replaceText, "value")
        XCTAssertTrue(snapshot.findReplaceState.isFindPanelVisible)
        XCTAssertTrue(snapshot.isWorkspaceSymbolSearchPresented)
        XCTAssertTrue(snapshot.isCallHierarchyPresented)
        XCTAssertEqual(snapshot.scrollState.viewportOrigin, CGPoint(x: 7, y: 11))
    }

    func testBridgeStateControllerBuildsStateFromViewStateAndFindState() {
        let bridgeState = EditorBridgeStateController.state(
            viewState: .init(
                primaryCursorLine: 12,
                primaryCursorColumn: 5,
                cursorPositions: [
                    CursorPosition(start: .init(line: 12, column: 5), end: nil)
                ]
            ),
            findReplaceState: .init(findText: "x", replaceText: "y", isFindPanelVisible: true)
        )

        XCTAssertEqual(bridgeState.viewState.primaryCursorLine, 12)
        XCTAssertEqual(bridgeState.viewState.primaryCursorColumn, 5)
        XCTAssertEqual(bridgeState.findReplaceState?.findText, "x")
        XCTAssertEqual(bridgeState.findReplaceState?.replaceText, "y")
        XCTAssertTrue(bridgeState.findReplaceState?.isFindPanelVisible == true)
    }

    func testBridgeStateControllerUsesProvidedFallbackForObservedPositions() {
        let bridgeState = EditorBridgeStateController.state(
            cursorPositions: [],
            fallbackLine: 14,
            fallbackColumn: 9
        )

        XCTAssertEqual(bridgeState.viewState.primaryCursorLine, 14)
        XCTAssertEqual(bridgeState.viewState.primaryCursorColumn, 9)
        XCTAssertTrue(bridgeState.viewState.cursorPositions.isEmpty)
    }

    func testSessionSnapshotBuilderPreservesProvidedSessionID() {
        let sessionID = UUID()
        let snapshot = EditorSessionSnapshotBuilder.snapshot(
            preserving: sessionID,
            fileURL: URL(fileURLWithPath: "/tmp/demo.swift"),
            multiCursorState: MultiCursorState(
                primary: .init(location: 0, length: 0),
                secondary: [.init(location: 4, length: 2)]
            ),
            panelState: .init(
                mouseHoverContent: "hover",
                mouseHoverSymbolRect: .init(x: 1, y: 2, width: 3, height: 4),
                referenceResults: [],
                isReferencePanelPresented: true,
                isWorkspaceSymbolSearchPresented: true,
                isCallHierarchyPresented: false,
                problemDiagnostics: [],
                selectedProblemDiagnostic: nil,
                isProblemsPanelPresented: false
            ),
            isDirty: true,
            findReplaceState: .init(findText: "a", replaceText: "b", isFindPanelVisible: true),
            scrollState: .init(viewportOrigin: CGPoint(x: 5, y: 9)),
            viewState: .init(primaryCursorLine: 3, primaryCursorColumn: 6, cursorPositions: [])
        )

        XCTAssertEqual(snapshot.id, sessionID)
        XCTAssertEqual(snapshot.fileURL?.lastPathComponent, "demo.swift")
        XCTAssertEqual(snapshot.multiCursorState.all.count, 2)
        XCTAssertEqual(snapshot.mouseHoverContent, "hover")
        XCTAssertTrue(snapshot.isReferencePanelPresented)
        XCTAssertTrue(snapshot.isWorkspaceSymbolSearchPresented)
        XCTAssertFalse(snapshot.isCallHierarchyPresented)
        XCTAssertTrue(snapshot.isDirty)
        XCTAssertEqual(snapshot.findReplaceState.findText, "a")
        XCTAssertEqual(snapshot.scrollState.viewportOrigin, CGPoint(x: 5, y: 9))
        XCTAssertEqual(snapshot.viewState.primaryCursorLine, 3)
        XCTAssertEqual(snapshot.viewState.primaryCursorColumn, 6)
    }

    func testSessionRestoreControllerUsesFallbackCursorPositionsWhenViewStateIsEmpty() {
        let session = EditorSession(
            fileURL: URL(fileURLWithPath: "/tmp/demo.swift"),
            findReplaceState: .init(findText: "needle", replaceText: "value", isFindPanelVisible: true),
            scrollState: .init(viewportOrigin: CGPoint(x: 8, y: 13)),
            viewState: .initial
        )
        let fallback = [
            CursorPosition(start: .init(line: 5, column: 2), end: nil)
        ]

        let result = EditorSessionRestoreController.restoreResult(
            from: session,
            fallbackCursorPositions: fallback
        )

        XCTAssertEqual(result.cursorLine, 5)
        XCTAssertEqual(result.cursorColumn, 2)
        XCTAssertEqual(result.findReplaceState.findText, "needle")
        XCTAssertEqual(result.scrollState.viewportOrigin, CGPoint(x: 8, y: 13))
        XCTAssertEqual(result.cursorPositions.count, 1)
        XCTAssertEqual(result.cursorPositions.first?.start.line, 5)
        XCTAssertEqual(result.cursorPositions.first?.start.column, 2)
    }

    func testMultiCursorStateControllerBuildsSortedState() {
        let state = EditorMultiCursorStateController.state(
            from: [
                .init(location: 9, length: 1),
                .init(location: 2, length: 0),
            ]
        )

        XCTAssertEqual(state.primary.location, 9)
        XCTAssertEqual(state.secondary.count, 1)
        XCTAssertEqual(state.all.first?.location, 2)
        XCTAssertEqual(state.all.last?.location, 9)
    }

    func testMultiCursorStateControllerReplacesPrimaryPreservingSecondary() {
        let original = MultiCursorState(
            primary: .init(location: 4, length: 0),
            secondary: [.init(location: 10, length: 2)]
        )

        let updated = EditorMultiCursorStateController.replacingPrimary(
            in: original,
            with: .init(location: 1, length: 3)
        )

        XCTAssertEqual(updated.primary.location, 1)
        XCTAssertEqual(updated.secondary.count, 1)
        XCTAssertEqual(updated.secondary.first?.location, 10)
    }

    func testEditorPanelStateAppliesSnapshot() {
        let state = EditorPanelState()

        state.apply(
            .init(
                isProblemsPanelPresented: true,
                isReferencePanelPresented: true,
                isWorkspaceSymbolSearchPresented: false,
                isCallHierarchyPresented: true
            )
        )

        XCTAssertTrue(state.isProblemsPanelPresented)
        XCTAssertTrue(state.isReferencePanelPresented)
        XCTAssertFalse(state.isWorkspaceSymbolSearchPresented)
        XCTAssertTrue(state.isCallHierarchyPresented)
    }

    func testEditorPanelStateAppliesCommandThroughController() {
        let state = EditorPanelState()
        state.isReferencePanelPresented = true

        state.apply(.toggleProblems)

        XCTAssertTrue(state.isProblemsPanelPresented)
        XCTAssertFalse(state.isReferencePanelPresented)
    }

    func testEditorPanelStateBuildsSessionState() {
        let state = EditorPanelState()
        state.problemDiagnostics = []
        state.selectedProblemDiagnostic = nil
        state.referenceResults = [
            .init(url: URL(fileURLWithPath: "/tmp/demo.swift"), line: 2, column: 3, path: "demo.swift", preview: "let demo = 1")
        ]
        state.isReferencePanelPresented = true
        state.setMouseHover(content: "hover", symbolRect: CGRect(x: 1, y: 2, width: 3, height: 4))
        state.isWorkspaceSymbolSearchPresented = true
        state.isCallHierarchyPresented = true

        let sessionState = state.sessionState

        XCTAssertEqual(sessionState.mouseHoverContent, "hover")
        XCTAssertEqual(sessionState.referenceResults.count, 1)
        XCTAssertTrue(sessionState.isReferencePanelPresented)
        XCTAssertTrue(sessionState.isWorkspaceSymbolSearchPresented)
        XCTAssertTrue(sessionState.isCallHierarchyPresented)
    }

    func testEditorPanelSessionStateBuildsSnapshot() {
        let sessionState = EditorPanelSessionState(
            isReferencePanelPresented: true,
            isWorkspaceSymbolSearchPresented: true,
            isCallHierarchyPresented: false,
            isProblemsPanelPresented: true
        )

        let snapshot = sessionState.snapshot

        XCTAssertTrue(snapshot.isProblemsPanelPresented)
        XCTAssertTrue(snapshot.isReferencePanelPresented)
        XCTAssertTrue(snapshot.isWorkspaceSymbolSearchPresented)
        XCTAssertFalse(snapshot.isCallHierarchyPresented)
    }

    func testEditorPanelStateRestoresFromSessionState() {
        let state = EditorPanelState()
        let diagnostic = Diagnostic(
            range: .init(
                start: .init(line: 0, character: 0),
                end: .init(line: 0, character: 2)
            ),
            severity: .warning,
            code: nil,
            codeDescription: nil,
            source: nil,
            message: "warn",
            relatedInformation: nil,
            tags: nil,
            data: nil
        )

        state.restore(
            from: .init(
                mouseHoverContent: "hover",
                mouseHoverSymbolRect: CGRect(x: 4, y: 6, width: 8, height: 10),
                referenceResults: [
                    .init(url: URL(fileURLWithPath: "/tmp/demo.swift"), line: 3, column: 5, path: "demo.swift", preview: "value")
                ],
                isReferencePanelPresented: true,
                isWorkspaceSymbolSearchPresented: true,
                isCallHierarchyPresented: false,
                problemDiagnostics: [diagnostic],
                selectedProblemDiagnostic: diagnostic,
                isProblemsPanelPresented: true
            )
        )

        XCTAssertEqual(state.mouseHoverContent, "hover")
        XCTAssertEqual(state.referenceResults.count, 1)
        XCTAssertEqual(state.problemDiagnostics, [diagnostic])
        XCTAssertEqual(state.selectedProblemDiagnostic, diagnostic)
        XCTAssertTrue(state.isReferencePanelPresented)
        XCTAssertTrue(state.isWorkspaceSymbolSearchPresented)
        XCTAssertFalse(state.isCallHierarchyPresented)
        XCTAssertTrue(state.isProblemsPanelPresented)
    }

    func testEditorStatePanelCommandUpdatesPanelStateAndLegacyFields() {
        let state = EditorState()
        state.panelState.isReferencePanelPresented = true

        state.performPanelCommand(.toggleProblems)

        XCTAssertTrue(state.isProblemsPanelPresented)
        XCTAssertTrue(state.panelState.isProblemsPanelPresented)
        XCTAssertFalse(state.isReferencePanelPresented)
        XCTAssertFalse(state.panelState.isReferencePanelPresented)
    }

    func testEditorStateMirrorsPanelStateHoverIntoLegacyFields() {
        let state = EditorState()

        state.panelState.setMouseHover(
            content: "hover",
            symbolRect: CGRect(x: 10, y: 20, width: 30, height: 40)
        )

        XCTAssertEqual(state.mouseHoverContent, "hover")
        XCTAssertEqual(state.hoverText, "hover")
        XCTAssertEqual(state.mouseHoverSymbolRect, CGRect(x: 10, y: 20, width: 30, height: 40))
        XCTAssertEqual(state.mouseHoverPoint, CGPoint(x: 25, y: 40))
        XCTAssertEqual(state.mouseHoverLine, 0)
        XCTAssertEqual(state.mouseHoverCharacter, 0)
    }

    func testEditorStateClearsHoverLegacyFieldsWhenPanelHoverCleared() {
        let state = EditorState()

        state.panelState.setMouseHover(
            content: "hover",
            symbolRect: CGRect(x: 10, y: 20, width: 30, height: 40)
        )
        state.panelState.clearMouseHover()

        XCTAssertNil(state.hoverText)
        XCTAssertNil(state.mouseHoverContent)
        XCTAssertEqual(state.mouseHoverSymbolRect, .zero)
        XCTAssertEqual(state.mouseHoverPoint, .zero)
    }

    func testEditorStateUpdatesSelectedProblemDiagnosticThroughPanelState() {
        let state = EditorState()
        let diagnostic = Diagnostic(
            range: .init(
                start: .init(line: 1, character: 2),
                end: .init(line: 1, character: 5)
            ),
            severity: .error,
            code: nil,
            codeDescription: nil,
            source: nil,
            message: "demo",
            relatedInformation: nil,
            tags: nil,
            data: nil
        )
        state.panelState.problemDiagnostics = [diagnostic]

        state.updateSelectedProblemDiagnostic(
            for: CursorPosition(start: .init(line: 2, column: 3), end: nil)
        )

        XCTAssertEqual(state.selectedProblemDiagnostic, diagnostic)
        XCTAssertEqual(state.panelState.selectedProblemDiagnostic, diagnostic)
    }

    func testEditorStateSessionRestoreRestoresPanelState() {
        let fileURL = URL(fileURLWithPath: "/tmp/demo.swift")
        let diagnostic = Diagnostic(
            range: .init(
                start: .init(line: 0, character: 0),
                end: .init(line: 0, character: 4)
            ),
            severity: .warning,
            code: nil,
            codeDescription: nil,
            source: nil,
            message: "warn",
            relatedInformation: nil,
            tags: nil,
            data: nil
        )
        let session = EditorSession(
            fileURL: fileURL,
            panelState: .init(
                mouseHoverContent: "hover",
                mouseHoverSymbolRect: CGRect(x: 4, y: 8, width: 12, height: 16),
                referenceResults: [
                    .init(url: fileURL, line: 2, column: 3, path: "demo.swift", preview: "let value = 1")
                ],
                isReferencePanelPresented: true,
                isWorkspaceSymbolSearchPresented: true,
                isCallHierarchyPresented: true,
                problemDiagnostics: [diagnostic],
                selectedProblemDiagnostic: diagnostic,
                isProblemsPanelPresented: true
            )
        )

        let state = EditorState()
        state.applySessionRestore(session)

        XCTAssertEqual(state.panelState.mouseHoverContent, "hover")
        XCTAssertEqual(state.panelState.referenceResults.count, 1)
        XCTAssertEqual(state.panelState.problemDiagnostics, [diagnostic])
        XCTAssertEqual(state.panelState.selectedProblemDiagnostic, diagnostic)
        XCTAssertTrue(state.panelState.isReferencePanelPresented)
        XCTAssertTrue(state.panelState.isWorkspaceSymbolSearchPresented)
        XCTAssertTrue(state.panelState.isCallHierarchyPresented)
        XCTAssertTrue(state.panelState.isProblemsPanelPresented)
    }
}
#endif
