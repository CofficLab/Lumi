#if canImport(XCTest)
import Foundation
import XCTest
@testable import EditorService

@MainActor
final class EditorServiceFacadeTests: XCTestCase {
    private func makeService() -> EditorService {
        EditorService(editorExtensionRegistry: EditorExtensionRegistry())
    }

    private func makeURL(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }

    func testOpenFileCreatesAndActivatesSession() {
        let service = makeService()
        let url = makeURL("Facade-A.swift")

        let session = service.openFile(at: url)

        XCTAssertNotNil(session)
        XCTAssertEqual(service.tabs.count, 1)
        XCTAssertEqual(service.activeSessionID, session?.id)
        XCTAssertEqual(service.session(for: session!.id)?.fileURL, url)
    }

    func testOpenFileReusesExistingSessionForSameURL() {
        let service = makeService()
        let url = makeURL("Facade-B.swift")

        let first = service.openFile(at: url)
        let second = service.openFile(at: url)

        XCTAssertEqual(service.tabs.count, 1)
        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(service.activeSessionID, first?.id)
    }

    func testCloseOtherSessionsKeepsOnlyRequestedSession() {
        let service = makeService()
        let a = service.openFile(at: makeURL("Facade-C-A.swift"))!
        _ = service.openFile(at: makeURL("Facade-C-B.swift"))
        _ = service.openFile(at: makeURL("Facade-C-C.swift"))

        _ = service.closeOtherSessions(keeping: a.id)

        XCTAssertEqual(service.tabs.count, 1)
        XCTAssertEqual(service.activeSessionID, a.id)
        XCTAssertNotNil(service.session(for: a.id))
    }

    func testNavigationBackAndForwardSwitchesActiveSession() {
        let service = makeService()
        let a = service.openFile(at: makeURL("Facade-D-A.swift"))!
        let b = service.openFile(at: makeURL("Facade-D-B.swift"))!

        let back = service.goBack()
        XCTAssertEqual(back?.id, a.id)
        XCTAssertEqual(service.activeSessionID, a.id)

        let forward = service.goForward()
        XCTAssertEqual(forward?.id, b.id)
        XCTAssertEqual(service.activeSessionID, b.id)
    }

    func testCloseAllSessionsClearsTabsAndActiveSession() {
        let service = makeService()
        _ = service.openFile(at: makeURL("Facade-E-A.swift"))
        _ = service.openFile(at: makeURL("Facade-E-B.swift"))

        service.closeAllSessions()

        XCTAssertTrue(service.tabs.isEmpty)
        XCTAssertNil(service.activeSessionID)
        XCTAssertNil(service.activeSession)
    }
}
#endif
