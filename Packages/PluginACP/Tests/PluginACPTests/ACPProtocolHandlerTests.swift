import Foundation
import XCTest
@testable import PluginACP
import ProviderACP
import ProviderAgentLoop
import ProviderMessage

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

    /// MainActor 隔离的消息收集盒。
    @MainActor
    private final class SentBox {
        var messages: [ACPMessage] = []
    }

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

    func testSessionPromptRejectsUnknownSession() throws {
        // 未知会话必须在同步路径回错误，否则客户端会永远等不到响应。
        handler.coordinator = ACPTurnCoordinator(
            agentLoop: NoopTurnRunner(),
            messages: NoopMessageStore(),
            sessions: sessions,
            requester: ACPClientRequester(onSend: { _ in }),
            onSend: { _ in }
        )
        let message = try ACPMessage.makeRequest(
            id: 5,
            method: ACPMethod.sessionPrompt,
            params: ACPPromptParams(
                sessionId: ACPSessionId(rawValue: "sess_does_not_exist"),
                prompt: [.text("hi")]
            )
        )
        let response = handler.handle(message)
        guard case .error(let id, let error) = response else {
            return XCTFail("期望错误响应，得到 \(String(describing: response))")
        }
        XCTAssertEqual(id, .number(5))
        XCTAssertEqual(error.code, ACPErrorCode.invalidParams)
        XCTAssertTrue(error.message.contains("Unknown session"))
    }

    // MARK: - Client 能力捕获

    func testInitializeCapturesFileSystemCapabilities() throws {
        XCTAssertFalse(handler.clientCapabilities.readTextFile)
        XCTAssertFalse(handler.clientCapabilities.writeTextFile)
        XCTAssertFalse(handler.clientCapabilities.hasFileSystemBridge)

        let message = try ACPMessage.makeRequest(
            id: 1,
            method: ACPMethod.initialize,
            params: ACPInitializeParams(
                protocolVersion: 1,
                clientCapabilities: ACPClientCapabilities(
                    fs: ACPFSClientCapabilities(readTextFile: true, writeTextFile: true)
                )
            )
        )
        _ = handler.handle(message)

        XCTAssertTrue(handler.clientCapabilities.readTextFile)
        XCTAssertTrue(handler.clientCapabilities.writeTextFile)
        XCTAssertTrue(handler.clientCapabilities.hasFileSystemBridge)
    }

    func testInitializeWithoutCapabilitiesKeepsDefaults() throws {
        let message = try ACPMessage.makeRequest(
            id: 1,
            method: ACPMethod.initialize,
            params: ACPInitializeParams(
                protocolVersion: 1,
                clientCapabilities: ACPClientCapabilities()
            )
        )
        _ = handler.handle(message)
        // 未声明一律视为不支持（ACP 要求）。
        XCTAssertFalse(handler.clientCapabilities.hasFileSystemBridge)
    }

    func testPartialFileSystemCapabilityIsNotBridgeable() throws {
        let message = try ACPMessage.makeRequest(
            id: 1,
            method: ACPMethod.initialize,
            params: ACPInitializeParams(
                protocolVersion: 1,
                clientCapabilities: ACPClientCapabilities(
                    fs: ACPFSClientCapabilities(readTextFile: true, writeTextFile: false)
                )
            )
        )
        _ = handler.handle(message)
        XCTAssertTrue(handler.clientCapabilities.readTextFile)
        XCTAssertFalse(handler.clientCapabilities.hasFileSystemBridge)
    }

    // MARK: - 出站响应路由

    func testResponseRoutesToRequesterByID() throws {
        let box = SentBox()
        let requester = ACPClientRequester { message in box.messages.append(message) }
        handler.requester = requester

        let started = expectation(description: "request resolved")
        Task { @MainActor in
            _ = try? await requester.request(
                method: ACPMethod.fsReadTextFile,
                params: .null,
                sessionID: nil
            )
            started.fulfill()
        }
        // 等待请求发出。
        let deadline = Date().addingTimeInterval(3)
        while box.messages.isEmpty && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        guard case .request(let id, _, _)? = box.messages.first else {
            return XCTFail("期望出站请求")
        }
        // 通过 handler 派发响应，应唤醒 requester。
        handler.handle(.response(id: id, result: .null))
        wait(for: [started], timeout: 3)
        XCTAssertEqual(requester.pendingCount, 0)
    }

    func testErrorResponseRoutesToRequester() throws {
        let box = SentBox()
        let requester = ACPClientRequester { message in box.messages.append(message) }
        handler.requester = requester

        var failure: Error?
        let done = expectation(description: "request failed")
        Task { @MainActor in
            do {
                _ = try await requester.request(
                    method: ACPMethod.fsReadTextFile,
                    params: .null,
                    sessionID: nil
                )
            } catch {
                failure = error
            }
            done.fulfill()
        }
        let deadline = Date().addingTimeInterval(3)
        while box.messages.isEmpty && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        guard case .request(let id, _, _)? = box.messages.first else {
            return XCTFail("期望出站请求")
        }
        handler.handle(.error(id: id, error: ACPError(code: ACPErrorCode.requestCancelled, message: "x")))
        wait(for: [done], timeout: 3)
        XCTAssertNotNil(failure)
    }
}


/// 未知会话测试用的最小桩（不会真正运行回合）。
@MainActor
private final class NoopTurnRunner: ACPTurnRunning {
    func addAgentLoopObserver(_ callback: @escaping (AgentLoopEvent) -> Void) -> any AgentLoopObserverHandle {
        NoopAgentLoopHandle()
    }
    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome { .completed }
    func cancelTurn(in conversationID: UUID) {}
    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {}
}

private final class NoopAgentLoopHandle: AgentLoopObserverHandle {
    func cancel() {}
}

@MainActor
private final class NoopMessageStore: ACPMessageReading {
    func insertMessage(_ message: Message, to conversationID: UUID) {}
    func messagesSnapshot(in conversationID: UUID) -> [Message] { [] }
}
