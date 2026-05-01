#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

@MainActor
final class EditorLSPActionControllerTests: XCTestCase {
    func testLanguageIDMapsKnownExtensions() {
        let controller = EditorLSPActionController()

        XCTAssertEqual(controller.languageID(for: "swift"), "swift")
        XCTAssertEqual(controller.languageID(for: "tsx"), "typescript")
        XCTAssertEqual(controller.languageID(for: "md"), "markdown")
    }

    func testReferenceResultsUseRelativePathAndSort() {
        let controller = EditorLSPActionController()
        let currentURL = URL(fileURLWithPath: "/tmp/project/file.swift")
        let otherURL = URL(fileURLWithPath: "/tmp/project/Sub/file2.swift")
        let locations = [
            Location(
                uri: otherURL.absoluteString,
                range: .init(start: .init(line: 4, character: 2), end: .init(line: 4, character: 3))
            ),
            Location(
                uri: currentURL.absoluteString,
                range: .init(start: .init(line: 0, character: 1), end: .init(line: 0, character: 2))
            )
        ]

        let results = controller.referenceResults(
            from: locations,
            currentFileURL: currentURL,
            relativeFilePath: "file.swift",
            projectRootPath: "/tmp/project",
            previewLine: { _, line in "line \(line)" }
        )

        XCTAssertEqual(results.map(\.path), ["Sub/file2.swift", "file.swift"])
        XCTAssertEqual(results.first?.preview, "line 5")
    }
}
#endif
