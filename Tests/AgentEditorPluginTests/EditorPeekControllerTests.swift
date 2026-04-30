#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

@MainActor
final class EditorPeekControllerTests: XCTestCase {
    func testBuildDefinitionPresentationUsesRelativePathAndPreview() {
        let controller = EditorPeekController()
        let url = URL(fileURLWithPath: "/tmp/Project/Sources/AppView.swift")
        let location = Location(
            uri: url.absoluteString,
            range: .init(
                start: .init(line: 1, character: 4),
                end: .init(line: 1, character: 10)
            )
        )

        let presentation = controller.buildDefinitionPresentation(
            location: location,
            currentFileURL: url,
            projectRootPath: "/tmp/Project",
            currentContent: "struct Root {}\nfunc renderApp() {}\n"
        )

        XCTAssertEqual(presentation?.mode, .definition)
        XCTAssertEqual(presentation?.items.first?.subtitle, "Sources/AppView.swift:2:5")
        XCTAssertEqual(presentation?.items.first?.preview, "func renderApp() {}")
    }

    func testBuildReferencesPresentationBuildsMultipleItems() {
        let controller = EditorPeekController()
        let firstURL = URL(fileURLWithPath: "/tmp/Project/Sources/A.swift")
        let secondURL = URL(fileURLWithPath: "/tmp/Project/Sources/B.swift")

        try? "let name = render\n".write(to: firstURL, atomically: true, encoding: .utf8)
        try? "render()\n".write(to: secondURL, atomically: true, encoding: .utf8)

        let locations = [
            Location(
                uri: firstURL.absoluteString,
                range: .init(start: .init(line: 0, character: 4), end: .init(line: 0, character: 10))
            ),
            Location(
                uri: secondURL.absoluteString,
                range: .init(start: .init(line: 0, character: 0), end: .init(line: 0, character: 6))
            )
        ]

        let presentation = controller.buildReferencesPresentation(
            locations: locations,
            currentFileURL: nil,
            relativeFilePath: "Sources/A.swift",
            projectRootPath: "/tmp/Project",
            currentContent: nil
        )

        XCTAssertEqual(presentation.mode, .references)
        XCTAssertEqual(presentation.items.count, 2)
        XCTAssertEqual(presentation.items.first?.badgeText, "Reference")
        XCTAssertTrue(presentation.summary.contains("2"))
    }
}
#endif
