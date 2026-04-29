#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class SourceEditorAdapterTests: XCTestCase {
    func testResolvedLanguageFallsBackToSwiftWhenUnset() {
        let adapter = SourceEditorAdapter()
        let state = EditorState()

        let language = adapter.resolvedLanguage(for: state)

        XCTAssertEqual(language.tsName, "swift")
    }

    func testActiveCoordinatorsFiltersNilEntries() {
        let adapter = SourceEditorAdapter()
        let state = EditorState()

        let coordinators = adapter.activeCoordinators(
            textCoordinator: EditorCoordinator(state: state),
            cursorCoordinator: nil,
            scrollCoordinator: ScrollCoordinator(state: state),
            contextMenuCoordinator: nil,
            hoverCoordinator: nil
        )

        XCTAssertEqual(coordinators.count, 2)
    }
}
#endif
