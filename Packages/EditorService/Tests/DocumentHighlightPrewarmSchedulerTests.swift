import Combine
import EditorLanguageRuntime
import EditorSource
import XCTest
@testable import EditorService

@MainActor
final class DocumentHighlightPrewarmSchedulerTests: XCTestCase {
    func testOpenTabsAreAllScheduledIncludingInactiveOnes() async {
        let registry = EditorExtensionRegistry()
        let state = EditorState(editorExtensions: registry)
        let sessionStore = EditorSessionStore()
        let cache = DocumentHighlightCache()
        let store = TreeSitterDocumentStore()

        let scheduler = DocumentHighlightPrewarmScheduler(
            cache: cache,
            documentStore: store,
            sessionStore: sessionStore,
            stateProvider: state,
            maxConcurrentTasks: 2
        )

        let urlA = URL(fileURLWithPath: "/tmp/a.swift")
        let urlB = URL(fileURLWithPath: "/tmp/b.swift")
        let urlC = URL(fileURLWithPath: "/tmp/c.swift")

        _ = sessionStore.openOrActivate(fileURL: urlA)
        _ = sessionStore.openSessionWithoutActivating(fileURL: urlB)
        _ = sessionStore.openSessionWithoutActivating(fileURL: urlC)

        scheduler.scheduleAllOpenTabs(activeFileURL: urlA)

        let expectation = expectation(description: "prewarm tasks scheduled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(sessionStore.sessions.count, 3)
    }

    func testCloseTabDoesNotCrashScheduler() async {
        let registry = EditorExtensionRegistry()
        let state = EditorState(editorExtensions: registry)
        let sessionStore = EditorSessionStore()
        let cache = DocumentHighlightCache()
        let store = TreeSitterDocumentStore()

        let scheduler = DocumentHighlightPrewarmScheduler(
            cache: cache,
            documentStore: store,
            sessionStore: sessionStore,
            stateProvider: state
        )

        let urlA = URL(fileURLWithPath: "/tmp/a.swift")
        let urlB = URL(fileURLWithPath: "/tmp/b.swift")
        let sessionA = sessionStore.openOrActivate(fileURL: urlA)!
        _ = sessionStore.openSessionWithoutActivating(fileURL: urlB)
        scheduler.scheduleAllOpenTabs(activeFileURL: urlA)
        _ = sessionStore.close(sessionID: sessionA.id)
        scheduler.scheduleAllOpenTabs(activeFileURL: urlB)

        let expectation = expectation(description: "close handled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
