#if canImport(XCTest)
import XCTest
import CodeEditSourceEditor
@testable import Lumi

@MainActor
final class SourceEditorViewBridgeTests: XCTestCase {
    func testLineTableUsesCurrentContent() {
        let bridge = SourceEditorViewBridge()
        let storage = NSTextStorage(string: "one\ntwo\n")

        let lineTable = bridge.lineTable(for: storage)

        XCTAssertNotNil(lineTable)
        XCTAssertEqual(lineTable?.lineCount, 3)
        XCTAssertEqual(lineTable?.lineStart(line: 0), 0)
        XCTAssertEqual(lineTable?.lineStart(line: 1), 4)
    }

    func testBindingClearsScrollPositionOnRead() {
        let bridge = SourceEditorViewBridge()
        let state = EditorState()
        state.editorState.scrollPosition = CGPoint(x: 10, y: 20)

        let value = bridge.binding(for: state).wrappedValue

        XCTAssertNil(value.scrollPosition)
    }
}
#endif
