#if canImport(XCTest)
import XCTest
@testable import Lumi

final class EditorSelectionMapperTests: XCTestCase {

    // MARK: - shouldAcceptCanonicalUpdate

    func testAcceptSingleToSingle() {
        let current = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 0))
        ])
        let view = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 10, length: 0))
        ])
        XCTAssertTrue(EditorSelectionMapper.shouldAcceptCanonicalUpdate(
            viewSelections: view,
            currentState: current
        ))
    }

    func testAcceptMultiToMore() {
        let current = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 0)),
            EditorSelection(range: EditorRange(location: 20, length: 0)),
        ])
        let view = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 0)),
            EditorSelection(range: EditorRange(location: 20, length: 0)),
            EditorSelection(range: EditorRange(location: 30, length: 0)),
        ])
        XCTAssertTrue(EditorSelectionMapper.shouldAcceptCanonicalUpdate(
            viewSelections: view,
            currentState: current
        ))
    }

    func testRejectMultiToLess() {
        // 模拟 CodeEdit 内部选区丢失：内核有 3 个光标，原生回传只有 1 个
        let current = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 0)),
            EditorSelection(range: EditorRange(location: 20, length: 0)),
            EditorSelection(range: EditorRange(location: 30, length: 0)),
        ])
        let view = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 0))
        ])
        XCTAssertFalse(EditorSelectionMapper.shouldAcceptCanonicalUpdate(
            viewSelections: view,
            currentState: current
        ))
    }

    func testAcceptSameCount() {
        let current = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 0)),
            EditorSelection(range: EditorRange(location: 20, length: 0)),
        ])
        let view = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 10, length: 0)),
            EditorSelection(range: EditorRange(location: 20, length: 0)),
        ])
        XCTAssertTrue(EditorSelectionMapper.shouldAcceptCanonicalUpdate(
            viewSelections: view,
            currentState: current
        ))
    }
}
#endif
