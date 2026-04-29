#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorWorkspaceEditControllerTests: XCTestCase {
    func testApplyRoutesCurrentAndExternalDocumentEdits() {
        let controller = EditorWorkspaceEditController()
        var currentReasons: [String] = []
        var externalURLs: [URL] = []

        let changedFiles = controller.apply(
            changes: [
                "file:///current.swift": [TextEdit(range: .init(start: .init(line: 0, character: 0), end: .init(line: 0, character: 0)), newText: "a")],
                "file:///tmp/other.swift": [TextEdit(range: .init(start: .init(line: 0, character: 0), end: .init(line: 0, character: 0)), newText: "b")]
            ],
            documentChanges: nil,
            currentURI: "file:///current.swift"
        ) { _, reason in
            currentReasons.append(reason)
        } applyExternalFileEdits: { _, url in
            externalURLs.append(url)
            return true
        }

        XCTAssertEqual(changedFiles, 2)
        XCTAssertEqual(currentReasons, ["lsp_workspace_edit"])
        XCTAssertEqual(externalURLs.map(\.path), ["/tmp/other.swift"])
    }
}
#endif
