#if canImport(XCTest)
import XCTest
@testable import Lumi

final class EditorSavePipelineControllerTests: XCTestCase {
    func testPrepareAppliesTextParticipantsBeforeFormatting() async {
        let result = await EditorSavePipelineController.prepare(
            text: "alpha   ",
            options: .init(
                textParticipants: .default,
                formatOnSave: true,
                organizeImportsOnSave: false,
                fixAllOnSave: false
            ),
            tabSize: 4,
            insertSpaces: true,
            formatDocument: { text, _, _ in
                XCTAssertEqual(text, "alpha\n")
                return text.uppercased()
            }
        )

        XCTAssertEqual(result.text, "ALPHA\n")
        XCTAssertTrue(result.didApplyTextParticipants)
        XCTAssertTrue(result.didFormat)
    }

    func testPrepareSkipsFormattingWhenDisabled() async {
        let result = await EditorSavePipelineController.prepare(
            text: "alpha",
            options: .init(
                textParticipants: .default,
                formatOnSave: false,
                organizeImportsOnSave: false,
                fixAllOnSave: false
            ),
            tabSize: 4,
            insertSpaces: true,
            formatDocument: { _, _, _ in
                XCTFail("formatDocument should not be called when formatOnSave is disabled")
                return nil
            }
        )

        XCTAssertEqual(result.text, "alpha\n")
        XCTAssertTrue(result.didApplyTextParticipants)
        XCTAssertFalse(result.didFormat)
    }

    func testPrepareIgnoresUnchangedFormattingOutput() async {
        let result = await EditorSavePipelineController.prepare(
            text: "alpha\n",
            options: .init(
                textParticipants: .default,
                formatOnSave: true,
                organizeImportsOnSave: false,
                fixAllOnSave: false
            ),
            tabSize: 4,
            insertSpaces: true,
            formatDocument: { text, _, _ in
                text
            }
        )

        XCTAssertEqual(result.text, "alpha\n")
        XCTAssertFalse(result.didApplyTextParticipants)
        XCTAssertFalse(result.didFormat)
        XCTAssertEqual(result.deferredActions, [])
    }

    func testPrepareCollectsDeferredSaveActionsInStableOrder() async {
        let result = await EditorSavePipelineController.prepare(
            text: "alpha\n",
            options: .init(
                textParticipants: .default,
                formatOnSave: false,
                organizeImportsOnSave: true,
                fixAllOnSave: true
            ),
            tabSize: 4,
            insertSpaces: true
        )

        XCTAssertEqual(result.deferredActions, [.organizeImports, .fixAll])
    }

    func testPrepareCollectsNoDeferredActionsWhenDisabled() async {
        let result = await EditorSavePipelineController.prepare(
            text: "alpha\n",
            options: .init(
                textParticipants: .default,
                formatOnSave: false,
                organizeImportsOnSave: false,
                fixAllOnSave: false
            ),
            tabSize: 4,
            insertSpaces: true
        )

        XCTAssertEqual(result.deferredActions, [])
    }
}
#endif
