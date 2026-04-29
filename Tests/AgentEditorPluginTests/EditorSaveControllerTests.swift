#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorSaveControllerTests: XCTestCase {
    func testPipelineOptionsReflectFlags() {
        let controller = EditorSaveController()

        let options = controller.pipelineOptions(
            trimTrailingWhitespace: false,
            insertFinalNewline: true,
            formatOnSave: true,
            organizeImportsOnSave: false,
            fixAllOnSave: true
        )

        XCTAssertFalse(options.textParticipants.trimTrailingWhitespace)
        XCTAssertTrue(options.textParticipants.insertFinalNewline)
        XCTAssertTrue(options.formatOnSave)
        XCTAssertFalse(options.organizeImportsOnSave)
        XCTAssertTrue(options.fixAllOnSave)
    }

    func testPerformSaveCallsSuccessPath() async {
        let controller = EditorSaveController()
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let expectation = expectation(description: "save succeeds")
        controller.performSave(
            content: "hello",
            url: fileURL,
            onMissingFile: {
                XCTFail("expected file to exist")
            },
            writeFile: { content, url in
                try content.write(to: url, atomically: true, encoding: .utf8)
            },
            onSuccess: {
                expectation.fulfill()
            },
            onFailure: { error in
                XCTFail("unexpected error: \(error)")
            }
        )

        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
#endif
