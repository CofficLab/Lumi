#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorMultiCursorSearchControllerTests: XCTestCase {
    func testStartedSessionSeedsHistoryWithBaseSelection() {
        let baseSelection = MultiCursorSelection(location: 4, length: 3)

        let session = EditorMultiCursorSearchController.startedSession(
            query: "foo",
            baseSelection: baseSelection
        )

        XCTAssertEqual(session.query, "foo")
        XCTAssertEqual(session.baseSelection, baseSelection)
        XCTAssertEqual(session.history, [baseSelection])
    }

    func testShouldReuseRequiresMatchingBaseAndCurrentSelectionText() {
        let session = EditorMultiCursorSearchController.startedSession(
            query: "foo",
            baseSelection: .init(location: 0, length: 3)
        )

        XCTAssertTrue(
            EditorMultiCursorSearchController.shouldReuse(
                session: session,
                baseSelectionText: "foo",
                currentSelectionText: "foo"
            )
        )
        XCTAssertFalse(
            EditorMultiCursorSearchController.shouldReuse(
                session: session,
                baseSelectionText: "bar",
                currentSelectionText: "foo"
            )
        )
        XCTAssertFalse(
            EditorMultiCursorSearchController.shouldReuse(
                session: session,
                baseSelectionText: "foo",
                currentSelectionText: nil
            )
        )
    }

    func testNextSelectionSkipsAlreadySelectedMatches() {
        let baseSelection = MultiCursorSelection(location: 0, length: 3)
        let session = EditorMultiCursorSearchController.startedSession(
            query: "foo",
            baseSelection: baseSelection
        )
        let currentState = MultiCursorState(
            primary: baseSelection,
            secondary: [.init(location: 8, length: 3)]
        )
        let matches = [
            baseSelection,
            .init(location: 8, length: 3),
            .init(location: 16, length: 3)
        ]

        let next = EditorMultiCursorSearchController.nextSelection(
            in: matches,
            currentState: currentState,
            session: session
        )

        XCTAssertEqual(next, .init(location: 16, length: 3))
    }

    func testNextSelectionReturnsNilWhenAllMatchesAlreadySelected() {
        let baseSelection = MultiCursorSelection(location: 0, length: 3)
        let session = EditorMultiCursorSearchController.startedSession(
            query: "foo",
            baseSelection: baseSelection
        )
        let matches = [
            baseSelection,
            .init(location: 8, length: 3)
        ]
        let currentState = MultiCursorState(
            primary: baseSelection,
            secondary: [.init(location: 8, length: 3)]
        )

        let next = EditorMultiCursorSearchController.nextSelection(
            in: matches,
            currentState: currentState,
            session: session
        )

        XCTAssertNil(next)
    }

    func testRemovingLastReturnsUpdatedSessionUntilOnlyBaseRemains() {
        let session = EditorMultiCursorSearchController.allOccurrencesSession(
            query: "foo",
            baseSelection: .init(location: 0, length: 3),
            matches: [
                .init(location: 0, length: 3),
                .init(location: 8, length: 3),
                .init(location: 16, length: 3)
            ]
        )

        let updated = EditorMultiCursorSearchController.removingLast(from: session)

        XCTAssertEqual(updated?.history, [
            .init(location: 0, length: 3),
            .init(location: 8, length: 3)
        ])
        XCTAssertNil(
            EditorMultiCursorSearchController.removingLast(
                from: EditorMultiCursorSearchController.startedSession(
                    query: "foo",
                    baseSelection: .init(location: 0, length: 3)
                )
            )
        )
    }

    func testResolvedContextReusesExistingSessionWhenTextsStillMatch() {
        let text = "foo bar foo" as NSString
        let session = EditorMultiCursorSearchController.startedSession(
            query: "foo",
            baseSelection: .init(location: 0, length: 3)
        )

        let resolved = EditorMultiCursorSearchController.resolvedContext(
            from: NSRange(location: 0, length: 3),
            in: text,
            existingSession: session
        )

        XCTAssertEqual(
            resolved,
            EditorMultiCursorResolvedContext(
                context: .init(baseSelection: .init(location: 0, length: 3), query: "foo"),
                shouldStartSession: false
            )
        )
    }

    func testResolvedContextBuildsNewContextWhenNoReusableSessionExists() {
        let text = "alpha beta" as NSString

        let resolved = EditorMultiCursorSearchController.resolvedContext(
            from: NSRange(location: 7, length: 0),
            in: text,
            existingSession: nil
        )

        XCTAssertEqual(
            resolved,
            EditorMultiCursorResolvedContext(
                context: .init(baseSelection: .init(location: 6, length: 4), query: "beta"),
                shouldStartSession: true
            )
        )
    }

    func testCollapsedSessionKeepsOnlyBaseSelectionWhenQueryStillMatches() {
        let text = "foo bar foo" as NSString
        let session = EditorMultiCursorSearchController.allOccurrencesSession(
            query: "foo",
            baseSelection: .init(location: 0, length: 3),
            matches: [
                .init(location: 0, length: 3),
                .init(location: 8, length: 3)
            ]
        )

        let collapsed = EditorMultiCursorSearchController.collapsedSession(
            from: session,
            singleSelection: .init(location: 0, length: 3),
            in: text
        )

        XCTAssertEqual(
            collapsed,
            EditorMultiCursorSearchSession(
                query: "foo",
                baseSelection: .init(location: 0, length: 3),
                history: [.init(location: 0, length: 3)]
            )
        )
    }

    func testCollapsedSessionReturnsNilWhenSelectionNoLongerMatchesQuery() {
        let text = "bar bar foo" as NSString
        let session = EditorMultiCursorSearchController.startedSession(
            query: "foo",
            baseSelection: .init(location: 0, length: 3)
        )

        let collapsed = EditorMultiCursorSearchController.collapsedSession(
            from: session,
            singleSelection: .init(location: 0, length: 3),
            in: text
        )

        XCTAssertNil(collapsed)
    }
}
#endif
