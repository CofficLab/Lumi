import Foundation
import XCTest
@testable import PluginACP
import ProviderACP

@MainActor
final class ACPSessionManagerTests: XCTestCase {
    private final class MockConversationFactory: ACPSessionCreating {
        var nextConversationID = UUID()
        var createdCount = 0
        var lastProjectPath: String?
        var failNext = false

        func createConversation(
            title: String?,
            projectPath: String?,
            providerID: String?,
            modelName: String?
        ) throws -> UUID {
            if failNext { throw TestError.createFailed }
            createdCount += 1
            lastProjectPath = projectPath
            return nextConversationID
        }

        enum TestError: Error { case createFailed }
    }

    private var factory: MockConversationFactory!
    private var manager: ACPSessionManager!

    override func setUp() {
        super.setUp()
        factory = MockConversationFactory()
        manager = ACPSessionManager(conversationFactory: factory)
    }

    func testCreateSessionMapsToConversation() throws {
        let sessionID = try manager.createSession(cwd: "/tmp/project")
        XCTAssertEqual(factory.createdCount, 1)
        XCTAssertEqual(factory.lastProjectPath, "/tmp/project")
        XCTAssertEqual(manager.conversationID(for: sessionID), factory.nextConversationID)
        XCTAssertEqual(manager.sessionID(for: factory.nextConversationID), sessionID)
        XCTAssertEqual(manager.sessionCount, 1)
    }

    func testSessionIDFormat() throws {
        let sessionID = try manager.createSession(cwd: "/tmp/project")
        XCTAssertTrue(sessionID.rawValue.hasPrefix("sess_"))
        // sess_ + 32 位小写十六进制
        let hexPart = sessionID.rawValue.dropFirst("sess_".count)
        XCTAssertEqual(hexPart.count, 32)
        // 数字无大小写；字母必须为小写。
        XCTAssertTrue(hexPart.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    func testMultipleSessionsAreIndependent() throws {
        let a = try manager.createSession(cwd: "/a")
        factory.nextConversationID = UUID()
        let b = try manager.createSession(cwd: "/b")

        XCTAssertNotEqual(a, b)
        XCTAssertEqual(manager.sessionCount, 2)
        XCTAssertNotEqual(manager.conversationID(for: a), manager.conversationID(for: b))
        XCTAssertEqual(manager.record(for: a)?.cwd, "/a")
        XCTAssertEqual(manager.record(for: b)?.cwd, "/b")
    }

    func testRemoveSessionCleansBothMappings() throws {
        let sessionID = try manager.createSession(cwd: "/tmp/project")
        let conversationID = factory.nextConversationID

        manager.removeSession(sessionID)

        XCTAssertNil(manager.conversationID(for: sessionID))
        XCTAssertNil(manager.sessionID(for: conversationID))
        XCTAssertEqual(manager.sessionCount, 0)
    }

    func testCreateSessionPropagatesFailure() {
        factory.failNext = true
        XCTAssertThrowsError(try manager.createSession(cwd: "/tmp/project"))
        XCTAssertEqual(manager.sessionCount, 0)
    }

    func testRecordCarriesCreatedAt() throws {
        let sessionID = try manager.createSession(cwd: "/tmp/project")
        let record = try XCTUnwrap(manager.record(for: sessionID))
        XCTAssertEqual(record.conversationID, factory.nextConversationID)
        XCTAssertEqual(record.cwd, "/tmp/project")
        XCTAssertLessThanOrEqual(record.createdAt.timeIntervalSinceNow, 1)
    }
}
