import Foundation
import XCTest
@testable import PluginACP
import ProviderACP

@MainActor
final class ACPProtocolHandlerTests: XCTestCase {
    private final class MockConversationFactory: ACPSessionCreating {
        var nextConversationID = UUID()
        func createConversation(
            title: String?,
            projectPath: String?,
            providerID: String?,
            modelName: String?
        ) throws -> UUID {
            nextConversationID
        }
    }

    private var factory: MockConversationFactory!
    private var sessions: ACPSessionManager!
    private var handler: ACPProtocolHandler!

    override func setUp() {
        super.setUp()
        factory = MockConversationFactory()
        sessions = ACPSessionManager(conversationFactory: factory)
        handler = ACPProtocolHandler(config: .default, sessions: sessions)
    }

    // MARK: - initialize

    func testInitializeReturnsHandshakeResult() throws {
        let message = try ACPMessage.makeRequest(
            id: 1,
            method: ACPMethod.initialize,
            params: ACPInitializeParams(
                protocolVersion: 1,
                clientCapabilities: ACPClientCapabilities(),
                clientInfo: nil
            )
        )
        let response = handler.handle(message)
        guard case .response(let id, let result) = response else {
            return XCTFail("期望成功响应，得到 \(String(describing: response))")
        }
        XCTAssertEqual(id, .number(1))
        let decoded = try result?.decoded(as: ACPInitializeResult.self)
        XCTAssertEqual(decoded?.protocolVersion, 1)
        XCTAssertEqual(decoded?.agentInfo?.name, ACPConfig.default.agentName)
        XCTAssertEqual(decoded?.agentCapabilities.loadSession, false)
        XCTAssertEqual(decoded?.authMethods, [])
    }

    func testInitializeAcceptsOlderOrNewerVersion() throws {
        // Agent 只支持 1：Client 请求 0 或 2 时，Agent 仍应答 1。
        for requested in [0, 2] {
            let message = try ACPMessage.makeRequest(
                id: 9,
                method: ACPMethod.initialize,
                params: ACPInitializeParams(
                    protocolVersion: requested,
                    clientCapabilities: ACPClientCapabilities()
                )
            )
            let response = handler.handle(message)
            guard case .response(_, let result) = response else {
                return XCTFail("版本 \(requested) 应得到成功响应")
            }
            let decoded = try result?.decoded(as: ACPInitializeResult.self)
            XCTAssertEqual(decoded?.protocolVersion, 1)
        }
    }

    func testInitializeRejectsMissingParams() throws {
        let message = try ACPMessage.makeRequest(id: 1, method: ACPMethod.initialize, params: JSONValue.null)
        let response = handler.handle(message)
        guard case .error(let id, let error) = response else {
            return XCTFail("期望错误响应")
        }
        XCTAssertEqual(id, .number(1))
        XCTAssertEqual(error.code, ACPErrorCode.invalidParams)
    }

    // MARK: - session/new

    func testSessionNewCreatesMappedSession() throws {
        let message = try ACPMessage.makeRequest(
            id: 2,
            method: ACPMethod.sessionNew,
            params: ACPSessionNewParams(cwd: "/tmp/project")
        )
        let response = handler.handle(message)
        guard case .response(let id, let result) = response else {
            return XCTFail("期望成功响应，得到 \(String(describing: response))")
        }
        XCTAssertEqual(id, .number(2))
        let decoded = try result?.decoded(as: ACPSessionNewResult.self)
        let sessionID = try XCTUnwrap(decoded?.sessionId)
        XCTAssertTrue(sessionID.rawValue.hasPrefix("sess_"))
        XCTAssertEqual(sessions.conversationID(for: sessionID), factory.nextConversationID)
        XCTAssertEqual(sessions.sessionCount, 1)
    }

    func testSessionNewRejectsEmptyCwd() throws {
        let message = try ACPMessage.makeRequest(
            id: 3,
            method: ACPMethod.sessionNew,
            params: ACPSessionNewParams(cwd: "")
        )
        let response = handler.handle(message)
        guard case .error(let id, let error) = response else {
            return XCTFail("期望错误响应")
        }
        XCTAssertEqual(id, .number(3))
        XCTAssertEqual(error.code, ACPErrorCode.invalidParams)
    }

    func testSessionNewRejectsMissingParams() throws {
        let message = try ACPMessage.makeRequest(id: 3, method: ACPMethod.sessionNew, params: JSONValue.null)
        let response = handler.handle(message)
        guard case .error = response else {
            return XCTFail("期望错误响应")
        }
    }

    // MARK: - 其他

    func testUnknownMethodReturnsMethodNotFound() throws {
        let message = try ACPMessage.makeRequest(id: 7, method: "session/unknown", params: JSONValue.null)
        let response = handler.handle(message)
        guard case .error(let id, let error) = response else {
            return XCTFail("期望错误响应")
        }
        XCTAssertEqual(id, .number(7))
        XCTAssertEqual(error.code, ACPErrorCode.methodNotFound)
    }

    func testNotificationIsIgnored() throws {
        let message = try ACPMessage.makeNotification(method: "session/update", params: JSONValue.null)
        XCTAssertNil(handler.handle(message))
    }
}
