#if canImport(XCTest)
import Foundation
import XCTest
@testable import EditorFileTreePlugin

@MainActor
final class EditorFileTreeSelectionStateTests: XCTestCase {
    private func url(_ path: String) -> URL {
        URL(fileURLWithPath: path)
    }

    func testPlainClickSelectsSingleItem() {
        let state = SelectionState()
        let file = url("/tmp/project/A.swift")
        var opened = false

        state.handleTap(
            url: file,
            isDirectory: false,
            modifiers: [],
            onOpenFile: { opened = true },
            onToggleExpand: {}
        )

        XCTAssertTrue(state.isSelected(file))
        XCTAssertTrue(opened)
    }

    func testCommandClickTogglesWithoutOpening() {
        let state = SelectionState()
        let fileA = url("/tmp/project/A.swift")
        let fileB = url("/tmp/project/B.swift")
        var openCount = 0

        state.handleTap(
            url: fileA,
            isDirectory: false,
            modifiers: [],
            onOpenFile: { openCount += 1 },
            onToggleExpand: {}
        )
        state.handleTap(
            url: fileB,
            isDirectory: false,
            modifiers: [.command],
            onOpenFile: { openCount += 1 },
            onToggleExpand: {}
        )

        XCTAssertTrue(state.isSelected(fileA))
        XCTAssertTrue(state.isSelected(fileB))
        XCTAssertEqual(openCount, 1)
    }

    func testCommandClickAgainDeselectsItem() {
        let state = SelectionState()
        let file = url("/tmp/project/A.swift")

        state.handleTap(
            url: file,
            isDirectory: false,
            modifiers: [],
            onOpenFile: {},
            onToggleExpand: {}
        )
        state.handleTap(
            url: file,
            isDirectory: false,
            modifiers: [.command],
            onOpenFile: {},
            onToggleExpand: {}
        )

        XCTAssertFalse(state.isSelected(file))
    }

    func testShiftClickSelectsVisibleRange() {
        let state = SelectionState()
        let fileA = url("/tmp/project/A.swift")
        let fileB = url("/tmp/project/B.swift")
        let fileC = url("/tmp/project/C.swift")

        state.trackVisible(fileA)
        state.trackVisible(fileB)
        state.trackVisible(fileC)

        state.handleTap(
            url: fileA,
            isDirectory: false,
            modifiers: [],
            onOpenFile: {},
            onToggleExpand: {}
        )
        state.handleTap(
            url: fileC,
            isDirectory: false,
            modifiers: [.shift],
            onOpenFile: {},
            onToggleExpand: {}
        )

        XCTAssertTrue(state.isSelected(fileA))
        XCTAssertTrue(state.isSelected(fileB))
        XCTAssertTrue(state.isSelected(fileC))
    }

    func testShiftClickWithoutAnchorFallsBackToSingleSelection() {
        let state = SelectionState()
        let file = url("/tmp/project/A.swift")

        state.trackVisible(file)
        state.handleTap(
            url: file,
            isDirectory: false,
            modifiers: [.shift],
            onOpenFile: {},
            onToggleExpand: {}
        )

        XCTAssertTrue(state.isSelected(file))
    }

    func testSyncFromEditorHighlightCollapsesMultiSelection() {
        let state = SelectionState()
        let fileA = url("/tmp/project/A.swift")
        let fileB = url("/tmp/project/B.swift")

        state.handleTap(
            url: fileA,
            isDirectory: false,
            modifiers: [],
            onOpenFile: {},
            onToggleExpand: {}
        )
        state.handleTap(
            url: fileB,
            isDirectory: false,
            modifiers: [.command],
            onOpenFile: {},
            onToggleExpand: {}
        )

        state.syncFromEditorHighlight(fileA)

        XCTAssertTrue(state.isSelected(fileA))
        XCTAssertFalse(state.isSelected(fileB))
    }

    func testActionTargetsReturnsAllSelectedWhenContextIsInSelection() {
        let state = SelectionState()
        let fileA = url("/tmp/project/A.swift")
        let fileB = url("/tmp/project/B.swift")
        let fileC = url("/tmp/project/C.swift")

        state.trackVisible(fileA)
        state.trackVisible(fileB)
        state.trackVisible(fileC)

        state.handleTap(url: fileA, isDirectory: false, modifiers: [], onOpenFile: {}, onToggleExpand: {})
        state.handleTap(url: fileC, isDirectory: false, modifiers: [.command], onOpenFile: {}, onToggleExpand: {})

        let targets = state.actionTargets(for: fileC)
        XCTAssertEqual(targets.map(\.path), [fileA.path, fileC.path])
    }

    func testActionTargetsReturnsOnlyContextWhenSingleSelection() {
        let state = SelectionState()
        let fileA = url("/tmp/project/A.swift")

        state.handleTap(url: fileA, isDirectory: false, modifiers: [], onOpenFile: {}, onToggleExpand: {})

        let targets = state.actionTargets(for: fileA)
        XCTAssertEqual(targets, [fileA])
    }

    func testTopLevelURLsRemovesNestedPaths() {
        let folder = url("/tmp/project/Sources")
        let nested = url("/tmp/project/Sources/A.swift")
        let sibling = url("/tmp/project/README.md")

        let topLevel = PathFormatter.topLevelURLs(from: [folder, nested, sibling])
        XCTAssertEqual(Set(topLevel.map(\.path)), Set([folder.path, sibling.path]))
    }
}
#endif
