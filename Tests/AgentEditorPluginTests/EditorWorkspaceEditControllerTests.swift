#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
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

    func testSummarizeCountsFilesAndLocations() {
        let controller = EditorWorkspaceEditController()
        let summary = controller.summarize(
            WorkspaceEdit(
                changes: [
                    "file:///workspace/current.swift": [
                        TextEdit(
                            range: .init(start: .init(line: 0, character: 0), end: .init(line: 0, character: 1)),
                            newText: "value"
                        ),
                        TextEdit(
                            range: .init(start: .init(line: 2, character: 0), end: .init(line: 2, character: 1)),
                            newText: "value"
                        )
                    ],
                    "file:///workspace/other.swift": [
                        TextEdit(
                            range: .init(start: .init(line: 1, character: 0), end: .init(line: 1, character: 1)),
                            newText: "value"
                        )
                    ]
                ]
            ),
            currentURI: "file:///workspace/current.swift",
            projectRootPath: "/workspace"
        )

        XCTAssertEqual(summary.changedFiles, 2)
        XCTAssertEqual(summary.changedLocations, 3)
        XCTAssertEqual(summary.fileLabels, ["Current File", "other.swift"])
    }
}
#endif
