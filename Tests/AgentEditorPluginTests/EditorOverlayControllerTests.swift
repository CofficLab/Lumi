#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

@MainActor
final class EditorOverlayControllerTests: XCTestCase {
    func testSurfacePaletteUsesThemeSelectionForSelectedFindMatch() {
        let palette = EditorSurfaceOverlayPalette(theme: EditorThemeAdapter.fallbackTheme())

        let style = palette.style(for: .currentMatch)

        XCTAssertEqual(style.cornerRadius, 4)
        XCTAssertEqual(style.lineWidth, 1)
        XCTAssertGreaterThan(style.zIndex, 1)
    }

    func testInlinePresentationsIncludeMessageValueAndDiffContracts() {
        let controller = EditorOverlayController()
        let textView = TextView(string: "let value = demo(value)\n")
        textView.frame = CGRect(x: 0, y: 0, width: 320, height: 120)
        textView.layoutManager.ensureLayout(for: textView.textStorage)
        let lineTable = LineOffsetTable(content: textView.string)

        let presentations = controller.inlinePresentations(
            diagnostics: [
                makeDiagnostic(
                    startLine: 0,
                    startCharacter: 4,
                    endLine: 0,
                    endCharacter: 9,
                    severity: .warning,
                    message: "Value is unused"
                )
            ],
            selectedDiagnostic: nil,
            inlayHints: [
                InlayHintItem(
                    line: 0,
                    character: 15,
                    text: ": Int",
                    kind: .type,
                    tooltip: nil,
                    paddingLeft: true,
                    paddingRight: false
                )
            ],
            currentMatch: EditorFindMatch(
                range: EditorRange(location: 6, length: 4),
                matchedText: "beta"
            ),
            replacementText: "replacement-value",
            cursorLine: 1,
            textView: textView,
            lineTable: lineTable,
            containerSize: CGSize(width: 320, height: 120)
        )

        XCTAssertEqual(presentations.count, 3)
        XCTAssertTrue(presentations.contains { presentation in
            if case .message(.warning) = presentation.kind { return true }
            return false
        })
        XCTAssertTrue(presentations.contains { presentation in
            if case .value = presentation.kind { return true }
            return false
        })
        XCTAssertTrue(presentations.contains { presentation in
            if case .diff = presentation.kind { return true }
            return false
        })
        XCTAssertTrue(presentations.allSatisfy { $0.origin.x + $0.size.width <= 312 })
    }

    func testSurfacePaletteKeepsCurrentLineBehindBracketHighlights() {
        let palette = EditorSurfaceOverlayPalette(theme: EditorThemeAdapter.fallbackTheme())

        let currentLine = palette.style(for: .currentLine)
        let bracket = palette.style(for: .bracketMatch)

        XCTAssertEqual(currentLine.cornerRadius, 0)
        XCTAssertLessThan(currentLine.zIndex, bracket.zIndex)
    }

    func testHoverPlacementPrefersAboveWhenSpaceIsAvailable() {
        let controller = EditorOverlayController()

        let placement = controller.hoverOverlayOffset(
            symbolRect: CGRect(x: 120, y: 180, width: 48, height: 18),
            containerSize: CGSize(width: 640, height: 480),
            popoverSize: CGSize(width: 300, height: 120)
        )

        XCTAssertTrue(placement.isPresentedAboveSymbol)
        XCTAssertEqual(placement.anchor, .bottomLeading)
    }

    func testHoverPlacementFallsBelowNearTopEdge() {
        let controller = EditorOverlayController()

        let placement = controller.hoverOverlayOffset(
            symbolRect: CGRect(x: 120, y: 18, width: 48, height: 18),
            containerSize: CGSize(width: 640, height: 480),
            popoverSize: CGSize(width: 300, height: 120)
        )

        XCTAssertFalse(placement.isPresentedAboveSymbol)
        XCTAssertEqual(placement.anchor, .topLeading)
    }

    func testHoverPlacementClampsRightOverflow() {
        let controller = EditorOverlayController()

        let placement = controller.hoverOverlayOffset(
            symbolRect: CGRect(x: 620, y: 180, width: 24, height: 18),
            containerSize: CGSize(width: 640, height: 480),
            popoverSize: CGSize(width: 280, height: 120)
        )

        XCTAssertLessThanOrEqual(placement.origin.x + placement.cardSize.width, 632)
    }

    func testCodeActionIndicatorPlacementUsesLeadingGutterSpace() {
        let controller = EditorOverlayController()
        let textView = TextView(string: "alpha\nbeta\n")
        textView.frame = CGRect(x: 0, y: 0, width: 640, height: 300)
        textView.layoutManager.ensureLayout(for: textView.textStorage)
        let lineTable = LineOffsetTable(content: "alpha\nbeta\n")

        let placement = controller.codeActionIndicatorPlacement(
            cursorLine: 2,
            textView: textView,
            lineTable: lineTable,
            containerSize: CGSize(width: 640, height: 300)
        )

        XCTAssertNotNil(placement)
        XCTAssertGreaterThanOrEqual(placement?.origin.x ?? 0, 4)
        XCTAssertGreaterThan((placement?.panelOrigin.x ?? 0), (placement?.origin.x ?? 0))
    }

    func testSecondaryCursorHighlightsDifferentiateCaretAndSelection() {
        let controller = EditorOverlayController()
        let textView = TextView(string: "alpha\nbeta\n")
        textView.frame = CGRect(x: 0, y: 0, width: 320, height: 160)
        textView.layoutManager.ensureLayout(for: textView.textStorage)

        let highlights = controller.secondaryCursorHighlights(
            selections: [
                MultiCursorSelection(location: 1, length: 0),
                MultiCursorSelection(location: 6, length: 4)
            ],
            textView: textView,
            visibleRect: textView.visibleRect
        )

        XCTAssertEqual(highlights.count, 2)
        XCTAssertTrue(highlights.contains { $0.kind == .secondaryCaret })
        XCTAssertTrue(highlights.contains { $0.kind == .secondarySelection })
    }

    func testHoverOverlayTextRespectsPresentationFlag() {
        let controller = EditorOverlayController()

        XCTAssertNil(controller.hoverOverlayText(shouldPresent: false, hoverText: " demo "))
        XCTAssertEqual(controller.hoverOverlayText(shouldPresent: true, hoverText: " demo "), "demo")
    }

    func testCodeActionOverlayActionsHideWhenDisabled() {
        let controller = EditorOverlayController()
        let actions = [
            CodeActionItem(
                title: "Fix",
                kind: "quickfix",
                payload: .plugin(EditorCodeActionSuggestion(
                    id: "fix",
                    title: "Fix",
                    command: "editor.fix",
                    priority: 0
                )),
                isPreferred: false
            )
        ]

        XCTAssertTrue(controller.codeActionOverlayActions(shouldPresent: false, actions: actions).isEmpty)
        XCTAssertEqual(controller.codeActionOverlayActions(shouldPresent: true, actions: actions).count, 1)
    }

    func testInlinePresentationsPreferSelectedDiagnosticOnCursorLine() {
        let controller = EditorOverlayController()
        let textView = TextView(string: "alpha\nbeta\n")
        textView.frame = CGRect(x: 0, y: 0, width: 320, height: 160)
        textView.layoutManager.ensureLayout(for: textView.textStorage)
        let lineTable = LineOffsetTable(content: textView.string)
        let selected = makeDiagnostic(
            startLine: 1,
            startCharacter: 0,
            endLine: 1,
            endCharacter: 3,
            severity: .error,
            message: "selected"
        )
        let fallback = makeDiagnostic(
            startLine: 1,
            startCharacter: 1,
            endLine: 1,
            endCharacter: 2,
            severity: .warning,
            message: "fallback"
        )

        let presentations = controller.inlinePresentations(
            diagnostics: [fallback],
            selectedDiagnostic: selected,
            inlayHints: [],
            currentMatch: nil,
            replacementText: nil,
            cursorLine: 2,
            textView: textView,
            lineTable: lineTable,
            containerSize: CGSize(width: 320, height: 160)
        )

        XCTAssertEqual(presentations.first?.title, "selected")
    }

    func testGutterDecorationsPreferDiagnosticMarkerOverSymbolOnSameLane() {
        let controller = EditorOverlayController()
        let textView = TextView(string: "func demo() {\n    value()\n}\n")
        textView.frame = CGRect(x: 0, y: 0, width: 320, height: 160)
        textView.layoutManager.ensureLayout(for: textView.textStorage)
        let lineTable = LineOffsetTable(content: textView.string)

        let decorations = controller.gutterDecorations(
            diagnostics: [
                makeDiagnostic(
                    startLine: 0,
                    startCharacter: 0,
                    endLine: 0,
                    endCharacter: 4,
                    severity: .error,
                    message: "broken"
                )
            ],
            selectedDiagnostic: nil,
            documentSymbols: [
                EditorDocumentSymbolItem(
                    id: "demo",
                    name: "demo",
                    detail: nil,
                    kind: .function,
                    range: .init(start: .init(line: 0, character: 0), end: .init(line: 2, character: 0)),
                    selectionRange: .init(start: .init(line: 0, character: 5), end: .init(line: 0, character: 9)),
                    children: []
                )
            ],
            extensionSuggestions: [],
            textView: textView,
            lineTable: lineTable,
            renderRange: 0..<3
        )

        XCTAssertEqual(decorations.count, 2)
        XCTAssertTrue(decorations.contains { decoration in
            if case .diagnostic(.error) = decoration.kind { return decoration.lane == 0 }
            return false
        })
        XCTAssertTrue(decorations.contains { decoration in
            if case .symbol(.function) = decoration.kind { return decoration.lane == 1 }
            return false
        })
    }

    func testGutterDecorationsKeepHighestPriorityCustomDecorationPerLane() {
        let controller = EditorOverlayController()
        let textView = TextView(string: "alpha\nbeta\n")
        textView.frame = CGRect(x: 0, y: 0, width: 320, height: 160)
        textView.layoutManager.ensureLayout(for: textView.textStorage)
        let lineTable = LineOffsetTable(content: textView.string)

        let decorations = controller.gutterDecorations(
            diagnostics: [],
            selectedDiagnostic: nil,
            documentSymbols: [],
            extensionSuggestions: [
                EditorGutterDecorationSuggestion(
                    id: "git-modified",
                    line: 2,
                    lane: 2,
                    kind: .gitChange(.modified),
                    priority: 40
                ),
                EditorGutterDecorationSuggestion(
                    id: "custom-top",
                    line: 2,
                    lane: 2,
                    kind: .custom(name: "coverage", tone: .accent, symbolName: "drop.fill"),
                    priority: 90
                )
            ],
            textView: textView,
            lineTable: lineTable,
            renderRange: 0..<2
        )

        XCTAssertEqual(decorations.count, 1)
        XCTAssertEqual(decorations.first?.lane, 2)
        if case .custom(let name, _, let symbolName) = decorations.first?.kind {
            XCTAssertEqual(name, "coverage")
            XCTAssertEqual(symbolName, "drop.fill")
        } else {
            XCTFail("Expected custom gutter decoration to win highest-priority lane")
        }
    }

    private func makeDiagnostic(
        startLine: Int,
        startCharacter: Int,
        endLine: Int,
        endCharacter: Int,
        severity: DiagnosticSeverity,
        message: String
    ) -> Diagnostic {
        Diagnostic(
            range: .init(
                start: .init(line: startLine, character: startCharacter),
                end: .init(line: endLine, character: endCharacter)
            ),
            severity: severity,
            code: nil,
            codeDescription: nil,
            source: "Swift",
            message: message,
            tags: nil,
            relatedInformation: nil
        )
    }
}
#endif
