#if canImport(XCTest)
import EditorCodeEditTextView
import EditorKernel
import LanguageServerProtocol
import XCTest
@testable import EditorService

@MainActor
private final class MockSignatureHelpProvider: SuperEditorSignatureHelpProvider {
    var currentHelp: SignatureHelpItem?
    var isLoading: Bool = false
    var triggerCharacters: Set<String> = []
    var isAvailable: Bool = true
    private(set) var clearCount = 0

    func requestSignatureHelp(uri: String, line: Int, character: Int, preflight: (() -> Bool)?) async {}

    func clear() {
        clearCount += 1
        currentHelp = nil
    }

    func reset() {}
}

@MainActor
private final class MockDocumentHighlightProvider: SuperEditorDocumentHighlightProvider {
    var highlightRanges: [NSRange] = []
    var isActive: Bool = false
    private(set) var clearCount = 0

    func requestHighlight(uri: String, line: Int, character: Int, content: String) async {}

    func clear() {
        clearCount += 1
        highlightRanges = []
        isActive = false
    }

    func reset() {}
}

@MainActor
private final class MockCodeActionProvider: SuperEditorCodeActionProvider {
    var actions: [CodeActionItem] = []
    var isLoading: Bool = false
    var isVisible: Bool = false
    private(set) var clearCount = 0

    func requestCodeActions(uri: String, range: LSPRange, diagnostics: [Diagnostic]) async {}

    func requestCodeActionsForLine(
        uri: String,
        line: Int,
        character: Int,
        diagnostics: [Diagnostic],
        languageId: String,
        selectedText: String?
    ) async {}

    func performAction(
        _ item: CodeActionItem,
        textView: TextView?,
        documentURL: URL?,
        applyWorkspaceEditViaTransaction: ((WorkspaceEdit) -> Void)?,
        onFailureMessage: (String) -> Void
    ) async {}

    func clear() {
        clearCount += 1
        actions = []
        isVisible = false
    }

    func reset() {}
}

@MainActor
final class EditorViewportRuntimeTests: XCTestCase {
    private func makeStateWithOverlayProviders() -> (
        state: EditorState,
        signature: MockSignatureHelpProvider,
        highlights: MockDocumentHighlightProvider,
        codeActions: MockCodeActionProvider
    ) {
        let registry = EditorExtensionRegistry()
        let signature = MockSignatureHelpProvider()
        let highlights = MockDocumentHighlightProvider()
        let codeActions = MockCodeActionProvider()
        registry.registerSignatureHelpProvider(signature)
        registry.registerDocumentHighlightProvider(highlights)
        registry.registerCodeActionProvider(codeActions)
        return (
            state: EditorState(editorExtensions: registry),
            signature: signature,
            highlights: highlights,
            codeActions: codeActions
        )
    }

    func testViewportRenderControllerComputesBufferedRenderRange() {
        let controller = ViewportRenderController()

        controller.updateVisibleRange(startLine: 100, endLine: 120, totalLines: 1_000)

        XCTAssertEqual(controller.renderStartLine, 50)
        XCTAssertEqual(controller.renderEndLine, 170)
        XCTAssertTrue(controller.isLineVisible(50))
        XCTAssertTrue(controller.isLineVisible(169))
        XCTAssertFalse(controller.isLineVisible(49))
        XCTAssertFalse(controller.isLineVisible(170))
    }

    func testViewportRenderControllerClampsAtDocumentBounds() {
        let controller = ViewportRenderController()

        controller.updateVisibleRange(startLine: 10, endLine: 30, totalLines: 1_000)
        XCTAssertEqual(controller.renderStartLine, 0)
        XCTAssertEqual(controller.renderEndLine, 80)

        controller.updateVisibleRange(startLine: 980, endLine: 1_000, totalLines: 1_000)
        XCTAssertEqual(controller.renderStartLine, 930)
        XCTAssertEqual(controller.renderEndLine, 1_000)
    }

    func testViewportRenderControllerDebounceDecisionTracksScrollDelta() {
        let controller = ViewportRenderController()
        controller.updateVisibleRange(startLine: 100, endLine: 120, totalLines: 1_000)

        XCTAssertTrue(controller.shouldDebounceUpdate(from: 102, previousEndLine: 118))
        XCTAssertFalse(controller.shouldDebounceUpdate(from: 200, previousEndLine: 220))
    }

    func testEditorRuntimeModeControllerViewportFeatureRules() {
        XCTAssertTrue(EditorRuntimeModeController.isViewportFeatureEnabled(viewportRange: 0..<0, maxLine: 1_000))
        XCTAssertTrue(EditorRuntimeModeController.isViewportFeatureEnabled(viewportRange: 500..<800, maxLine: 1_000))
        XCTAssertFalse(EditorRuntimeModeController.isViewportFeatureEnabled(viewportRange: 1_000..<1_200, maxLine: 1_000))
    }

    func testEditorRuntimeModeControllerDisablesSyntaxFeaturesWhenLongLineProtectionApplies() {
        XCTAssertTrue(
            EditorRuntimeModeController.isLongLineProtectionSuppressingSyntaxHighlighting(
                largeFileMode: .large,
                longestDetectedLine: LongestDetectedLine(line: 8, length: 20_000)
            )
        )
        XCTAssertFalse(
            EditorRuntimeModeController.isLongLineProtectionSuppressingSyntaxHighlighting(
                largeFileMode: .medium,
                longestDetectedLine: LongestDetectedLine(line: 8, length: 20_000)
            )
        )
        XCTAssertFalse(
            EditorRuntimeModeController.isViewportSyntaxFeatureEnabled(
                viewportRange: 0..<100,
                maxLine: 10_000,
                largeFileMode: .large,
                longestDetectedLine: LongestDetectedLine(line: 3, length: 15_000)
            )
        )
        XCTAssertTrue(
            EditorRuntimeModeController.isViewportSyntaxFeatureEnabled(
                viewportRange: 200..<400,
                maxLine: 1_000,
                largeFileMode: .medium,
                longestDetectedLine: nil
            )
        )
    }

    func testEditorStateApplyViewportObservationUpdatesMirroredRanges() {
        let state = EditorState(editorExtensions: EditorExtensionRegistry())

        state.applyViewportObservation(startLine: 100, endLine: 120, totalLines: 1_000)

        XCTAssertEqual(state.viewportVisibleLineRange, 100..<120)
        XCTAssertEqual(state.viewportRenderLineRange, 50..<170)
        XCTAssertEqual(state.viewportRenderController.totalLines, 1_000)
    }

    func testEditorStateRenderedRangeHelpersUseViewportRenderRange() {
        let state = EditorState(editorExtensions: EditorExtensionRegistry())
        state.applyViewportObservation(startLine: 2, endLine: 3, totalLines: 10)

        let lineTable = LineOffsetTable(content: "a\nbb\nccc\ndddd\n")
        let matches = [
            EditorFindMatch(range: EditorRange(location: 0, length: 1), matchedText: "a"),
            EditorFindMatch(range: EditorRange(location: 2, length: 2), matchedText: "bb"),
        ]
        let hints = [
            InlayHintItem(line: 0, character: 0, text: "a", kind: nil, tooltip: nil, paddingLeft: false, paddingRight: false),
            InlayHintItem(line: 2, character: 0, text: "b", kind: nil, tooltip: nil, paddingLeft: false, paddingRight: false),
        ]

        XCTAssertTrue(state.isRenderedLine(0))
        XCTAssertTrue(state.isRenderedLine(2))
        XCTAssertTrue(state.isRenderedOffset(2, lineTable: lineTable))
        XCTAssertTrue(state.intersectsRenderedRange(EditorRange(location: 2, length: 2), lineTable: lineTable))
        XCTAssertEqual(state.renderedFindMatches(matches, lineTable: lineTable).count, 2)
        XCTAssertEqual(state.renderedInlayHints(hints).count, 2)
    }

    func testEditorStateRenderedRangeHelpersFilterOutOfViewportContent() {
        let state = EditorState(editorExtensions: EditorExtensionRegistry())
        state.applyViewportObservation(startLine: 100, endLine: 120, totalLines: 200)

        let lines = Array(repeating: "abcd", count: 200).joined(separator: "\n")
        let lineTable = LineOffsetTable(content: lines)
        let outsideRange = EditorRange(location: 0, length: 4)
        let insideOffset = lineTable.lineStart(line: 105) ?? 0
        let insideRange = EditorRange(location: insideOffset, length: 4)
        let matches = [
            EditorFindMatch(range: outsideRange, matchedText: "abcd"),
            EditorFindMatch(range: insideRange, matchedText: "abcd"),
        ]
        let hints = [
            InlayHintItem(line: 10, character: 0, text: "outside", kind: nil, tooltip: nil, paddingLeft: false, paddingRight: false),
            InlayHintItem(line: 105, character: 0, text: "inside", kind: nil, tooltip: nil, paddingLeft: false, paddingRight: false),
        ]

        XCTAssertFalse(state.isRenderedLine(10))
        XCTAssertFalse(state.isRenderedOffset(0, lineTable: lineTable))
        XCTAssertFalse(state.intersectsRenderedRange(outsideRange, lineTable: lineTable))
        XCTAssertEqual(state.renderedFindMatches(matches, lineTable: lineTable).count, 1)
        XCTAssertEqual(state.renderedInlayHints(hints).count, 1)
    }

    func testEditorStateResetViewportObservationClearsRanges() {
        let state = EditorState(editorExtensions: EditorExtensionRegistry())
        state.applyViewportObservation(startLine: 100, endLine: 120, totalLines: 1_000)

        state.resetViewportObservation(totalLines: 50)

        XCTAssertEqual(state.viewportVisibleLineRange, 0..<0)
        XCTAssertEqual(state.viewportRenderLineRange, 0..<0)
        XCTAssertEqual(state.viewportRenderController.totalLines, 50)
    }

    func testEditorStateStaticViewportHelpersMirrorRuntimeModeController() {
        XCTAssertTrue(EditorState.isViewportFeatureEnabled(viewportRange: 0..<0, maxLine: 1_000))
        XCTAssertFalse(EditorState.isViewportFeatureEnabled(viewportRange: 1_000..<1_200, maxLine: 1_000))
        XCTAssertTrue(
            EditorState.isViewportSyntaxFeatureEnabled(
                viewportRange: 100..<200,
                maxLine: 1_000,
                largeFileMode: .medium,
                longestDetectedLine: nil
            )
        )
        XCTAssertTrue(
            EditorState.isLongLineProtectionSuppressingSyntaxHighlighting(
                largeFileMode: .mega,
                longestDetectedLine: LongestDetectedLine(line: 0, length: 20_000)
            )
        )
    }

    func testEditorStatePresentsSignatureHelpOverlayWhenCursorIsRendered() {
        let fixture = makeStateWithOverlayProviders()
        fixture.signature.currentHelp = SignatureHelpItem(
            label: "foo(bar: Int)",
            documentation: nil,
            parameters: [SignatureParam(label: "bar: Int", documentation: nil)],
            activeParameterIndex: 0
        )

        fixture.state.applyViewportObservation(startLine: 0, endLine: 20, totalLines: 100)

        XCTAssertTrue(fixture.state.shouldPresentSignatureHelpOverlay)
        XCTAssertEqual(fixture.state.currentSignatureHelpOverlayItem?.label, "foo(bar: Int)")
    }

    func testEditorStateHidesOverlaysWhenPrimaryCursorFallsOutsideRenderedViewport() {
        let fixture = makeStateWithOverlayProviders()
        fixture.signature.currentHelp = SignatureHelpItem(
            label: "foo(bar: Int)",
            documentation: nil,
            parameters: [SignatureParam(label: "bar: Int", documentation: nil)],
            activeParameterIndex: 0
        )
        fixture.codeActions.actions = [
            CodeActionItem(
                title: "Fix It",
                kind: "quickfix",
                payload: .plugin(
                    EditorCodeActionSuggestion(
                        id: "fix-it",
                        title: "Fix It",
                        command: "editor.fixIt",
                        priority: 0
                    )
                ),
                isPreferred: false
            ),
        ]
        fixture.codeActions.isVisible = true

        fixture.state.applyViewportObservation(startLine: 100, endLine: 120, totalLines: 200)

        XCTAssertFalse(fixture.state.shouldPresentSignatureHelpOverlay)
        XCTAssertNil(fixture.state.currentSignatureHelpOverlayItem)
        XCTAssertFalse(fixture.state.shouldPresentCodeActionOverlay)
        XCTAssertTrue(fixture.state.currentCodeActionOverlayActions.isEmpty)
    }

    func testEditorStateHandleViewportRuntimeTransitionClearsTransientProviders() {
        let fixture = makeStateWithOverlayProviders()
        fixture.signature.currentHelp = SignatureHelpItem(
            label: "foo()",
            documentation: nil,
            parameters: [],
            activeParameterIndex: 0
        )
        fixture.highlights.highlightRanges = [NSRange(location: 0, length: 1)]
        fixture.highlights.isActive = true
        fixture.codeActions.actions = [
            CodeActionItem(
                title: "Fix It",
                kind: "quickfix",
                payload: .plugin(
                    EditorCodeActionSuggestion(
                        id: "fix-it",
                        title: "Fix It",
                        command: "editor.fixIt",
                        priority: 0
                    )
                ),
                isPreferred: false
            ),
        ]
        fixture.codeActions.isVisible = true

        fixture.state.applyViewportObservation(startLine: 100, endLine: 120, totalLines: 200)
        fixture.state.handleViewportRuntimeTransition()

        XCTAssertEqual(fixture.highlights.clearCount, 1)
        XCTAssertEqual(fixture.signature.clearCount, 1)
        XCTAssertEqual(fixture.codeActions.clearCount, 1)
    }

    func testEditorStateAvailabilityChangeHandlersClearOnlyWhenDisabling() {
        let fixture = makeStateWithOverlayProviders()

        fixture.state.handleDocumentHighlightRuntimeAvailabilityChange(true)
        fixture.state.handleSignatureHelpRuntimeAvailabilityChange(true)
        fixture.state.handleCodeActionRuntimeAvailabilityChange(true)
        XCTAssertEqual(fixture.highlights.clearCount, 0)
        XCTAssertEqual(fixture.signature.clearCount, 0)
        XCTAssertEqual(fixture.codeActions.clearCount, 0)

        fixture.state.handleDocumentHighlightRuntimeAvailabilityChange(false)
        fixture.state.handleSignatureHelpRuntimeAvailabilityChange(false)
        fixture.state.handleCodeActionRuntimeAvailabilityChange(false)
        XCTAssertEqual(fixture.highlights.clearCount, 1)
        XCTAssertEqual(fixture.signature.clearCount, 1)
        XCTAssertEqual(fixture.codeActions.clearCount, 1)
    }
}
#endif
