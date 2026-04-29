#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

@MainActor
final class EditorFormattingControllerTests: XCTestCase {
    func testPrepareSaveFormattingReturnsNilWhenNoEdits() async {
        let controller = EditorFormattingController()

        let result = await controller.prepareSaveFormatting(
            text: "let a = 1",
            tabSize: 4,
            insertSpaces: true,
            requestFormatting: { _, _ in [] }
        )

        XCTAssertNil(result)
    }
}
#endif
