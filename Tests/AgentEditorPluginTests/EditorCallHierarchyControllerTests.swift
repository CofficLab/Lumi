#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorCallHierarchyControllerTests: XCTestCase {
    func testOpenCallHierarchyWarnsWhenRootItemMissing() async {
        let controller = EditorCallHierarchyController()
        var warning: String?
        var openedCommand: EditorPanelCommand?

        await controller.openCallHierarchy(
            currentFileURL: URL(fileURLWithPath: "/tmp/demo.swift"),
            cursorLine: 3,
            cursorColumn: 2,
            prepare: { _, _, _ in },
            hasRootItem: { false },
            showWarning: { warning = $0 },
            openPanel: { openedCommand = $0 }
        )

        XCTAssertEqual(warning, "未找到调用层级信息")
        XCTAssertNil(openedCommand)
    }
}
#endif
