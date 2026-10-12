import Foundation
import XCTest
@testable import PluginACP
import ProviderACP
import ProviderAgentLoop
import ProviderMessage

@MainActor
final class ACPTurnCoordinatorTests: XCTestCase {
    private final class NoopHandle: AgentLoopObserverHandle {
        func cancel() {}
    }

    /// Mock 回合执行器：可注入事件、记录调用。
    @MainActor
    private final class MockTurnRunner: ACPTurnRunning {
        var observer: ((AgentLoopEvent) -> Void)?
        var nextOutcome: AgentLoopOutcome = .suspended("test-waiting")
        var runCalls: [UUID] = []
        var resumeCalls: [AgentTurnResumeRequest] = []
        var cancelCalls: [UUID] = []
        var suppressedAutoReply: Set<UUID> = []

        func addAgentLoopObserver(
            _ callback: @escaping (AgentLoopEvent) -> Void
        ) -> any AgentLoopObserverHandle {
            observer = callback
            return NoopHandle()
        }

        func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
            runCalls.append(conversationID)
            return nextOutcome
        }

        func resumeTurn(
            in conversationID: UUID,
            request: AgentTurnResumeRequest
        ) async throws -> AgentLoopOutcome {
            resumeCalls.append(request)
            return .completed
        }

        func cancelTurn(in conversationID: UUID) {
            cancelCalls.append(conversationID)
        }

        func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {
            if suppressed {
                suppressedAutoReply.insert(conversationID)
            } else {
                suppressedAutoReply.remove(conversationID)
            }
        }

        func emit(_ event: AgentLoopEvent) {
            observer?(event)
        }
    }

    /// Mock 消息存储。
    @MainActor
    private final class MockMessageStore: ACPMessageReading {
        var messagesByConversation: [UUID: [Message]] = [:]

        func insertMessage(_ message: Message, to conversationID: UUID) {
            messagesByConversation[conversationID, default: []].append(message)
        }

        func messagesSnapshot(in conversationID: UUID) -> [Message] {
            messagesByConversation[conversationID] ?? []
        }
    }

    @MainActor
    private final class MockConversationFactory: ACPSessionCreating {
        var nextID = UUID()
        func createConversation(
            title: String?,
            projectPath: String?,
            providerID: String?,
            modelName: String?
        ) throws -> UUID {
            nextID
        }
    }

    /// MainActor 隔离的消息收集盒（闭包捕获安全）。
    @MainActor
    private final class SentBox {
        var messages: [ACPMessage] = []
    }

    /// 模拟 Client：记录 Agent 出站请求，并允许测试手动或自动回包。
    @MainActor
    private final class MockClient {
        private let box: SentBox
        private(set) var requests: [(id: JSONValue, method: String, params: JSONValue?)] = []
        /// 自动回包脚本：返回非 nil 即立即回复该结果。
        var autoRespond: ((String, JSONValue?) -> JSONValue?)? = nil
        private var requester: ACPClientRequester!

        init(box: SentBox) {
            self.box = box
        }

        func makeRequester() -> ACPClientRequester {
            let requester = ACPClientRequester { [weak self] message in
                self?.record(message)
            }
            self.requester = requester
            return requester
        }

        private func record(_ message: ACPMessage) {
            box.messages.append(message)
            guard case .request(let id, let method, let params) = message else { return }
            requests.append((id, method, params))
            if let autoRespond, let result = autoRespond(method, params) {
                requester.handleResponse(id: id, result: result)
            }
        }

        func lastRequest(method: String) -> (id: JSONValue, method: String, params: JSONValue?)? {
            requests.last { $0.method == method }
        }

        func respondToLast(method: String, result: JSONValue?) {
            guard let request = lastRequest(method: method) else { return }
            requester.handleResponse(id: request.id, result: result)
        }

        func failLast(method: String, error: ACPError) {
            guard let request = lastRequest(method: method) else { return }
            requester.handleError(id: request.id, error: error)
        }
    }

    /// 构造权限选择的响应载荷。
    private func permissionResult(_ optionId: String) -> JSONValue? {
        try? JSONValue.stringify(ACPRequestPermissionResult(outcome: .selected(optionId: optionId)))
    }

    private var cancelledResult: JSONValue? {
        try? JSONValue.stringify(ACPRequestPermissionResult(outcome: .cancelled))
    }

    private var runner: MockTurnRunner!
    private var store: MockMessageStore!
    private var sessions: ACPSessionManager!
    private var box: SentBox!
    private var client: MockClient!
    private var coordinator: ACPTurnCoordinator!

    override func setUp() {
        super.setUp()
        runner = MockTurnRunner()
        store = MockMessageStore()
        sessions = ACPSessionManager(conversationFactory: MockConversationFactory())
        box = SentBox()
        client = MockClient(box: box)
        coordinator = ACPTurnCoordinator(
            agentLoop: runner,
            messages: store,
            sessions: sessions,
            requester: client.makeRequester(),
            onSend: { [box] message in
                box.messages.append(message)
            }
        )
    }

    /// 便捷：已发送消息列表。
    private var sent: [ACPMessage] { box.messages }

    private func waitUntil(
        _ condition: () -> Bool,
        timeout: TimeInterval = 3.0
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    private func makeSessionID() throws -> ACPSessionId {
        try sessions.createSession(cwd: "/tmp/project")
    }

    /// 解析最近一次 `session/request_permission` 的参数。
    private func permissionParams() throws -> ACPRequestPermissionParams? {
        guard let request = client.lastRequest(method: ACPMethod.sessionRequestPermission) else {
            return nil
        }
        return try request.params?.decoded(as: ACPRequestPermissionParams.self)
    }

    /// 上报一次工具调用（授权流程的前置条件）。
    private func reportToolCall(
        conversationID: UUID,
        id: String,
        name: String = "write_file",
        arguments: String = #"{"path":"/tmp/a.swift"}"#
    ) {
        runner.emit(.toolCallsReceived(
            conversationID: conversationID,
            turnID: UUID(),
            assistantMessageID: UUID(),
            toolCalls: [MessageToolCall(id: id, name: name, arguments: arguments)]
        ))
    }

    // MARK: - 回合完成

    func testStartTurnInsertsUserMessageAndRunsTurn() async throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))

        let error = coordinator.startTurn(
            sessionID: sessionID,
            requestID: .number(1),
            prompt: [.text("修复这个 bug")]
        )
        XCTAssertNil(error)
        waitUntil { self.runner.runCalls.contains(conversationID) }

        let messages = store.messagesByConversation[conversationID] ?? []
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.role, .user)
        XCTAssertEqual(messages.first?.content, "修复这个 bug")
    }

    func testCompletedTurnSendsTextAndEndTurnResult() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))

        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        store.messagesByConversation[conversationID, default: []].append(
            Message(conversationID: conversationID, role: .assistant, content: "已修复")
        )
        runner.emit(.completed(conversationID: conversationID, turnID: UUID()))
        runner.nextOutcome = .completed
        waitUntil { self.sent.contains { $0.id == .number(1) } }

        guard let response = sent.first(where: { $0.id == .number(1) }),
              case .response(_, let result) = response else {
            return XCTFail("期望最终响应")
        }
        let decoded = try result?.decoded(as: ACPPromptResult.self)
        XCTAssertEqual(decoded?.stopReason, .endTurn)

        XCTAssertTrue(sent.contains {
            if case .notification(let method, let params) = $0 {
                return method == ACPMethod.sessionUpdate &&
                    (try? params?.decoded(as: ACPSessionUpdateParams.self))?.update ==
                    SessionUpdate.agentMessageChunk(.text("已修复"))
            }
            return false
        })
    }

    func testCompletedFinalizesOnlyOnce() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))

        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }
        store.messagesByConversation[conversationID, default: []].append(
            Message(conversationID: conversationID, role: .assistant, content: "ok")
        )
        // 事件与 runTurn 返回双路径：只应产生一个响应。
        runner.emit(.completed(conversationID: conversationID, turnID: UUID()))
        runner.nextOutcome = .completed
        waitUntil { self.sent.contains { $0.id == .number(1) } }
        waitUntil { self.sent.filter { $0.id == .number(1) }.count >= 1 }

        XCTAssertEqual(sent.filter { $0.id == .number(1) }.count, 1)
    }

    // MARK: - 工具调用

    func testToolCallsReceivedEmitsToolCallNotification() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        reportToolCall(conversationID: conversationID, id: "call_001", name: "bash", arguments: #"{"cmd":"ls"}"#)

        waitUntil { self.sent.count >= 1 }
        XCTAssertTrue(sent.contains {
            guard case .notification(let method, let params) = $0 else { return false }
            guard method == ACPMethod.sessionUpdate,
                  let update = try? params?.decoded(as: ACPSessionUpdateParams.self) else { return false }
            switch update.update {
            case .toolCall(let tc):
                return tc.toolCallId == "call_001" && tc.kind == .execute && tc.status == .pending
            default:
                return false
            }
        })
    }

    func testFinalizePublishesToolResultUpdates() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        let call = MessageToolCall(
            id: "call_001",
            name: "bash",
            arguments: #"{"cmd":"ls"}"#,
            result: MessageToolResult(content: "main.swift", isError: false)
        )
        store.messagesByConversation[conversationID, default: []].append(
            Message(conversationID: conversationID, role: .assistant, content: "执行完成", toolCalls: [call])
        )
        runner.emit(.completed(conversationID: conversationID, turnID: UUID()))
        runner.nextOutcome = .completed
        waitUntil { self.sent.contains { $0.id == .number(1) } }

        XCTAssertTrue(sent.contains {
            guard case .notification(_, let params) = $0,
                  let update = try? params?.decoded(as: ACPSessionUpdateParams.self) else { return false }
            switch update.update {
            case .toolCallUpdate(let tc):
                return tc.toolCallId == "call_001" && tc.status == .completed
            default:
                return false
            }
        })
    }

    // MARK: - AskUser 权限桥

    func testSuspendedYesNoRequestsPermission() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        let suspension = AgentLoopSuspension(
            suspensionID: "userInput:call_001",
            conversationID: conversationID,
            toolCallID: "call_001",
            kind: "userInput",
            payload: #"{"mode":"yes_no","question":"继续构建?"}"#
        )
        runner.emit(.suspended(conversationID: conversationID, turnID: UUID(), suspension: suspension))

        waitUntil { self.client.lastRequest(method: ACPMethod.sessionRequestPermission) != nil }
        // optionId 稳定为 yes/no；展示名走本地化（内容随语言变化，不硬断言）。
        XCTAssertEqual(try permissionParams()?.options.map(\.optionId), ["yes", "no"])

        client.respondToLast(method: ACPMethod.sessionRequestPermission, result: permissionResult("yes"))
        waitUntil { self.runner.resumeCalls.count == 1 }
        XCTAssertEqual(runner.resumeCalls.first?.suspensionID, "userInput:call_001")
        // answer 必须是内核 resolveUserResponse 认可的允许词，不能随界面语言变化。
        XCTAssertEqual(runner.resumeCalls.first?.answer, "approved")
    }

    func testSuspendedChoiceRequestsPermissionWithOptions() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        let suspension = AgentLoopSuspension(
            suspensionID: "userInput:call_002",
            conversationID: conversationID,
            toolCallID: "call_002",
            kind: "userInput",
            payload: #"{"mode":"choice","question":"选哪个配置?","options":[{"label":"Debug"},{"label":"Release"}]}"#
        )
        runner.emit(.suspended(conversationID: conversationID, turnID: UUID(), suspension: suspension))

        waitUntil { self.client.lastRequest(method: ACPMethod.sessionRequestPermission) != nil }
        XCTAssertEqual(try permissionParams()?.options.map(\.name), ["Debug", "Release"])

        client.respondToLast(method: ACPMethod.sessionRequestPermission, result: permissionResult("Release"))
        waitUntil { self.runner.resumeCalls.count == 1 }
        // choice 的 answer 就是选项标签本身。
        XCTAssertEqual(runner.resumeCalls.first?.answer, "Release")
    }

    func testSuspendedFreeTextDegradesToTextAndCancel() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        let suspension = AgentLoopSuspension(
            suspensionID: "userInput:call_003",
            conversationID: conversationID,
            toolCallID: "call_003",
            kind: "userInput",
            payload: #"{"mode":"free_text","question":"想用什么分支名?"}"#
        )
        runner.emit(.suspended(conversationID: conversationID, turnID: UUID(), suspension: suspension))

        waitUntil { self.runner.cancelCalls.contains(conversationID) }
        // free_text 不应发起权限请求（ACP 无自由文本通道）。
        XCTAssertNil(client.lastRequest(method: ACPMethod.sessionRequestPermission))
        XCTAssertTrue(sent.contains {
            guard case .notification(_, let params) = $0,
                  let update = try? params?.decoded(as: ACPSessionUpdateParams.self),
                  case .agentMessageChunk(let content) = update.update,
                  case .text(let text, _) = content else { return false }
            return text.contains("想用什么分支名?")
        })
    }

    // MARK: - 工具授权（M4）

    func testToolPermissionUsesRealToolCallIDAndStandardOptions() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        reportToolCall(conversationID: conversationID, id: "call_write_1")
        let suspension = AgentLoopSuspension(
            suspensionID: "userInput:call_write_1",
            conversationID: conversationID,
            toolCallID: "call_write_1",
            kind: "userInput",
            // 内核授权挂起的 payload 携带 approval:<id>，但 ACP 必须用真实 toolCallId。
            payload: #"{"toolCallId":"approval:call_write_1","kind":"permission","question":"此操作被判定为高风险，是否允许执行？","options":["允许","拒绝"],"mode":"yes_no"}"#
        )
        runner.emit(.suspended(conversationID: conversationID, turnID: UUID(), suspension: suspension))

        waitUntil { self.client.lastRequest(method: ACPMethod.sessionRequestPermission) != nil }
        let params = try XCTUnwrap(try permissionParams())
        XCTAssertEqual(params.toolCall.toolCallId, "call_write_1")
        XCTAssertEqual(params.options.map(\.optionId), ["allow_once", "reject_once"])
        XCTAssertEqual(params.options.map(\.kind), [.allowOnce, .rejectOnce])
        // 上报的 tool_call 与授权请求必须指向同一个 id。
        XCTAssertTrue(sent.contains {
            guard case .notification(_, let p) = $0,
                  let update = try? p?.decoded(as: ACPSessionUpdateParams.self),
                  case .toolCall(let tc) = update.update else { return false }
            return tc.toolCallId == "call_write_1"
        })
    }

    func testToolPermissionAllowSendsInProgressAndResumes() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        reportToolCall(conversationID: conversationID, id: "call_write_1")
        runner.emit(.suspended(
            conversationID: conversationID,
            turnID: UUID(),
            suspension: AgentLoopSuspension(
                suspensionID: "userInput:call_write_1",
                conversationID: conversationID,
                toolCallID: "call_write_1",
                kind: "userInput",
                payload: #"{"kind":"permission","question":"允许吗?"}"#
            )
        ))
        waitUntil { self.client.lastRequest(method: ACPMethod.sessionRequestPermission) != nil }

        client.respondToLast(
            method: ACPMethod.sessionRequestPermission,
            result: permissionResult("allow_once")
        )
        waitUntil { self.runner.resumeCalls.count == 1 }
        // 允许词必须能被内核 resolveUserResponse 识别为"执行"。
        XCTAssertEqual(runner.resumeCalls.first?.answer, "approved")
        XCTAssertEqual(runner.resumeCalls.first?.suspensionID, "userInput:call_write_1")

        // 授权后应发 in_progress。
        waitUntil {
            self.sent.contains {
                guard case .notification(_, let p) = $0,
                      let update = try? p?.decoded(as: ACPSessionUpdateParams.self),
                      case .toolCallUpdate(let tc) = update.update else { return false }
                return tc.toolCallId == "call_write_1" && tc.status == .inProgress
            }
        }
    }

    func testToolPermissionRejectResumesWithRejectAnswer() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        reportToolCall(conversationID: conversationID, id: "call_write_2")
        runner.emit(.suspended(
            conversationID: conversationID,
            turnID: UUID(),
            suspension: AgentLoopSuspension(
                suspensionID: "userInput:call_write_2",
                conversationID: conversationID,
                toolCallID: "call_write_2",
                kind: "userInput",
                payload: #"{"kind":"permission","question":"允许吗?"}"#
            )
        ))
        waitUntil { self.client.lastRequest(method: ACPMethod.sessionRequestPermission) != nil }

        client.respondToLast(
            method: ACPMethod.sessionRequestPermission,
            result: permissionResult("reject_once")
        )
        waitUntil { self.runner.resumeCalls.count == 1 }
        // 非允许词 → 内核视为用户拒绝执行。
        XCTAssertEqual(runner.resumeCalls.first?.answer, "denied")
        // 拒绝不应发 in_progress。
        XCTAssertFalse(sent.contains {
            guard case .notification(_, let p) = $0,
                  let update = try? p?.decoded(as: ACPSessionUpdateParams.self),
                  case .toolCallUpdate(let tc) = update.update else { return false }
            return tc.toolCallId == "call_write_2" && tc.status == .inProgress
        })
    }

    func testPermissionCancelledOutcomeCancelsTurn() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        reportToolCall(conversationID: conversationID, id: "call_write_3")
        runner.emit(.suspended(
            conversationID: conversationID,
            turnID: UUID(),
            suspension: AgentLoopSuspension(
                suspensionID: "userInput:call_write_3",
                conversationID: conversationID,
                toolCallID: "call_write_3",
                kind: "userInput",
                payload: #"{"kind":"permission","question":"允许吗?"}"#
            )
        ))
        waitUntil { self.client.lastRequest(method: ACPMethod.sessionRequestPermission) != nil }

        // 规范：回合取消时 Client 以 cancelled outcome 回复权限请求。
        client.respondToLast(method: ACPMethod.sessionRequestPermission, result: cancelledResult)
        waitUntil { self.runner.cancelCalls.contains(conversationID) }
        XCTAssertTrue(runner.cancelCalls.contains(conversationID))
        XCTAssertTrue(runner.resumeCalls.isEmpty)
    }

    func testPermissionFailureCancelsTurn() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        reportToolCall(conversationID: conversationID, id: "call_write_4")
        runner.emit(.suspended(
            conversationID: conversationID,
            turnID: UUID(),
            suspension: AgentLoopSuspension(
                suspensionID: "userInput:call_write_4",
                conversationID: conversationID,
                toolCallID: "call_write_4",
                kind: "userInput",
                payload: #"{"kind":"permission","question":"允许吗?"}"#
            )
        ))
        waitUntil { self.client.lastRequest(method: ACPMethod.sessionRequestPermission) != nil }

        // Client 返回 JSON-RPC 错误（如连接异常）：不能悬挂，直接终止回合。
        client.failLast(
            method: ACPMethod.sessionRequestPermission,
            error: ACPError(code: ACPErrorCode.requestCancelled, message: "cancelled")
        )
        waitUntil { self.runner.cancelCalls.contains(conversationID) }
        XCTAssertTrue(runner.resumeCalls.isEmpty)
    }

    func testPermissionRequestTimeoutCancelsTurn() throws {
        let sessions = ACPSessionManager(conversationFactory: MockConversationFactory())
        let runner = MockTurnRunner()
        let store = MockMessageStore()
        let box = SentBox()
        let client = MockClient(box: box)
        let requester = ACPClientRequester(
            onSend: { message in box.messages.append(message) },
            timeout: 0.3,
            permissionTimeout: 0.3
        )
        let coordinator = ACPTurnCoordinator(
            agentLoop: runner,
            messages: store,
            sessions: sessions,
            requester: requester,
            onSend: { [box] message in box.messages.append(message) }
        )
        let sessionID = try sessions.createSession(cwd: "/tmp/timeout")
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { runner.runCalls.contains(conversationID) }

        runner.emit(.suspended(
            conversationID: conversationID,
            turnID: UUID(),
            suspension: AgentLoopSuspension(
                suspensionID: "userInput:call_t",
                conversationID: conversationID,
                toolCallID: "call_t",
                kind: "userInput",
                payload: #"{"kind":"permission","question":"允许吗?"}"#
            )
        ))
        // 不回复：请求超时后必须终止回合，而非永久悬挂。
        waitUntil({ runner.cancelCalls.contains(conversationID) }, timeout: 5.0)
        XCTAssertTrue(runner.cancelCalls.contains(conversationID))
        XCTAssertTrue(runner.resumeCalls.isEmpty)
    }

    // MARK: - 回合收尾清理挂起请求

    func testFinalizeMarksPendingToolCallsCancelled() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        reportToolCall(conversationID: conversationID, id: "call_pending")
        // 回合被取消：未出结果的工具调用应补发 cancelled。
        runner.emit(.cancelled(conversationID: conversationID, turnID: UUID()))
        runner.nextOutcome = .cancelled
        waitUntil { self.sent.contains { $0.id == .number(1) } }

        XCTAssertTrue(sent.contains {
            guard case .notification(_, let p) = $0,
                  let update = try? p?.decoded(as: ACPSessionUpdateParams.self),
                  case .toolCallUpdate(let tc) = update.update else { return false }
            return tc.toolCallId == "call_pending" && tc.status == .cancelled
        })
    }

    func testFinalizeCancelsPendingPermissionRequest() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        reportToolCall(conversationID: conversationID, id: "call_p")
        runner.emit(.suspended(
            conversationID: conversationID,
            turnID: UUID(),
            suspension: AgentLoopSuspension(
                suspensionID: "userInput:call_p",
                conversationID: conversationID,
                toolCallID: "call_p",
                kind: "userInput",
                payload: #"{"kind":"permission","question":"允许吗?"}"#
            )
        ))
        waitUntil { self.client.lastRequest(method: ACPMethod.sessionRequestPermission) != nil }

        // 回合因外部原因结束：挂起的权限请求必须被作废，不能残留。
        runner.emit(.cancelled(conversationID: conversationID, turnID: UUID()))
        runner.nextOutcome = .cancelled
        waitUntil { self.sent.contains { $0.id == .number(1) } }
        // 请求已被作废：之后再回包不应触发 resume。
        client.respondToLast(method: ACPMethod.sessionRequestPermission, result: permissionResult("allow_once"))
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertTrue(runner.resumeCalls.isEmpty)
    }

    func testSessionCancelCancelsPendingPermission() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        reportToolCall(conversationID: conversationID, id: "call_c")
        runner.emit(.suspended(
            conversationID: conversationID,
            turnID: UUID(),
            suspension: AgentLoopSuspension(
                suspensionID: "userInput:call_c",
                conversationID: conversationID,
                toolCallID: "call_c",
                kind: "userInput",
                payload: #"{"kind":"permission","question":"允许吗?"}"#
            )
        ))
        waitUntil { self.client.lastRequest(method: ACPMethod.sessionRequestPermission) != nil }

        coordinator.cancel(sessionID: sessionID)
        waitUntil { self.runner.cancelCalls.contains(conversationID) }

        // 取消后迟到的授权回包不得恢复回合。
        client.respondToLast(method: ACPMethod.sessionRequestPermission, result: permissionResult("allow_once"))
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertTrue(runner.resumeCalls.isEmpty)
    }

    // MARK: - 取消

    func testCancelSendsCancelledStopReason() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        runner.emit(.cancelled(conversationID: conversationID, turnID: UUID()))
        runner.nextOutcome = .cancelled
        waitUntil { self.sent.contains { $0.id == .number(1) } }

        guard let response = sent.first(where: { $0.id == .number(1) }),
              case .response(_, let result) = response else {
            return XCTFail("期望响应")
        }
        let decoded = try result?.decoded(as: ACPPromptResult.self)
        XCTAssertEqual(decoded?.stopReason, .cancelled)
    }

    // MARK: - 输入校验

    func testStartTurnRejectsUnknownSession() {
        let error = coordinator.startTurn(
            sessionID: ACPSessionId(rawValue: "sess_unknown"),
            requestID: .number(1),
            prompt: [.text("hi")]
        )
        XCTAssertNotNil(error)
    }

    func testStartTurnRejectsEmptyText() throws {
        let sessionID = try makeSessionID()
        let error = coordinator.startTurn(
            sessionID: sessionID,
            requestID: .number(1),
            prompt: [.image(mimeType: "image/png", data: "AA==", uri: nil, annotations: nil)]
        )
        XCTAssertNotNil(error)
    }

    func testStartTurnRejectsConcurrentTurn() throws {
        let sessionID = try makeSessionID()
        XCTAssertNil(coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("a")]))
        let error = coordinator.startTurn(sessionID: sessionID, requestID: .number(2), prompt: [.text("b")])
        XCTAssertNotNil(error)
    }

    // MARK: - 首响应超时兜底

    func testWatchdogFiresWhenNoLLMProgress() throws {
        let sessions = ACPSessionManager(conversationFactory: MockConversationFactory())
        let runner = MockTurnRunner()
        let store = MockMessageStore()
        let box = SentBox()
        let shortCoordinator = ACPTurnCoordinator(
            agentLoop: runner,
            messages: store,
            sessions: sessions,
            requester: ACPClientRequester(onSend: { _ in }),
            onSend: { [box] message in box.messages.append(message) },
            turnStartTimeout: 0.5
        )
        let sessionID = try sessions.createSession(cwd: "/tmp/wd")
        _ = shortCoordinator.startTurn(
            sessionID: sessionID,
            requestID: .number(1),
            prompt: [.text("hello")]
        )
        waitUntil({ box.messages.contains { $0.id == .number(1) } }, timeout: 3.0)
        guard let response = box.messages.first(where: { $0.id == .number(1) }),
              case .response(_, let result) = response else {
            return XCTFail("期望 watchdog 超时响应")
        }
        let decoded = try result?.decoded(as: ACPPromptResult.self)
        // 超时属于失败，必须如实上报 refusal，否则客户端会把错误当成功。
        XCTAssertEqual(decoded?.stopReason, .refusal)
        XCTAssertTrue(box.messages.contains {
            if case .notification(let method, let params) = $0,
               method == ACPMethod.sessionUpdate,
               let update = try? params?.decoded(as: ACPSessionUpdateParams.self),
               case .agentMessageChunk(let content) = update.update,
               case .text(let text, _) = content {
                return text.contains("no LLM progress")
            }
            return false
        })
    }

    func testWatchdogCancelledAfterLLMProgress() throws {
        let sessions = ACPSessionManager(conversationFactory: MockConversationFactory())
        let runner = MockTurnRunner()
        let store = MockMessageStore()
        let box = SentBox()
        let shortCoordinator = ACPTurnCoordinator(
            agentLoop: runner,
            messages: store,
            sessions: sessions,
            requester: ACPClientRequester(onSend: { _ in }),
            onSend: { [box] message in box.messages.append(message) },
            turnStartTimeout: 0.5
        )
        let sessionID = try sessions.createSession(cwd: "/tmp/wd2")
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = shortCoordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hello")])
        waitUntil { runner.runCalls.count == 1 }
        runner.emit(.toolCallsReceived(
            conversationID: conversationID,
            turnID: UUID(),
            assistantMessageID: UUID(),
            toolCalls: [MessageToolCall(id: "c1", name: "bash", arguments: #"{}"#)]
        ))
        store.messagesByConversation[conversationID, default: []].append(
            Message(conversationID: conversationID, role: .assistant, content: "ok")
        )
        runner.emit(.completed(conversationID: conversationID, turnID: UUID()))
        waitUntil({ box.messages.contains { $0.id == .number(1) } }, timeout: 3.0)
        let responses = box.messages.filter { $0.id == .number(1) }
        XCTAssertEqual(responses.count, 1)
        guard let response = responses.first, case .response(_, let result) = response else {
            return XCTFail("期望响应")
        }
        let decoded = try result?.decoded(as: ACPPromptResult.self)
        XCTAssertEqual(decoded?.stopReason, .endTurn)
    }

    // MARK: - 流式输出

    /// 可手动推进的流式 store mock。
    @MainActor
    private final class MockStream: ACPStreamObserving {
        var observer: ((UUID) -> Void)?
        var contentByConversation: [UUID: String] = [:]

        func addACPStreamObserver(_ callback: @escaping (UUID) -> Void) -> any ACPStreamObserverHandle {
            observer = callback
            return NoopStreamHandle()
        }

        func acpStreamingContent(for conversationID: UUID) -> String? {
            contentByConversation[conversationID]
        }

        /// 模拟内核追加一段 token。
        func append(_ text: String, to conversationID: UUID) {
            contentByConversation[conversationID, default: ""] += text
            observer?(conversationID)
        }
    }

    private final class NoopStreamHandle: ACPStreamObserverHandle {
        func cancel() {}
    }

    func testStreamingEmitsIncrementalChunks() throws {
        let sessions = ACPSessionManager(conversationFactory: MockConversationFactory())
        let runner = MockTurnRunner()
        let store = MockMessageStore()
        let box = SentBox()
        let stream = MockStream()
        let coordinator = ACPTurnCoordinator(
            agentLoop: runner,
            messages: store,
            sessions: sessions,
            requester: ACPClientRequester(onSend: { _ in }),
            streaming: ACPStreamingBridge(stream: stream),
            onSend: { [box] message in box.messages.append(message) }
        )
        let sessionID = try sessions.createSession(cwd: "/tmp/stream")
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { runner.runCalls.contains(conversationID) }

        // 内核分两次追加 token。
        stream.append("你好", to: conversationID)
        stream.append("，世界", to: conversationID)

        let texts = box.messages.compactMap { message -> String? in
            guard case .notification(_, let params) = message,
                  let update = try? params?.decoded(as: ACPSessionUpdateParams.self),
                  case .agentMessageChunk(let content) = update.update,
                  case .text(let text, _) = content else { return nil }
            return text
        }
        // 必须是增量帧（而非等回合结束整段发）。
        XCTAssertEqual(texts, ["你好", "，世界"])
    }

    func testStreamedTurnDoesNotResendFullTextAtFinalize() throws {
        let sessions = ACPSessionManager(conversationFactory: MockConversationFactory())
        let runner = MockTurnRunner()
        let store = MockMessageStore()
        let box = SentBox()
        let stream = MockStream()
        let coordinator = ACPTurnCoordinator(
            agentLoop: runner,
            messages: store,
            sessions: sessions,
            requester: ACPClientRequester(onSend: { _ in }),
            streaming: ACPStreamingBridge(stream: stream),
            onSend: { [box] message in box.messages.append(message) }
        )
        let sessionID = try sessions.createSession(cwd: "/tmp/stream2")
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { runner.runCalls.contains(conversationID) }

        stream.append("完整答复", to: conversationID)
        // 收尾时落库一条相同的 assistant 消息。
        store.messagesByConversation[conversationID, default: []].append(
            Message(conversationID: conversationID, role: .assistant, content: "完整答复")
        )
        runner.emit(.completed(conversationID: conversationID, turnID: UUID()))
        runner.nextOutcome = .completed
        waitUntil { box.messages.contains { $0.id == .number(1) } }

        // 已流式发送过的文本不得在收尾时重复整段发送。
        // 流式那次本身就会产生一个等于全量的增量帧，因此这里断言"恰好一次"
        // ——收尾若再整段重发，就会出现第二次。
        let fullSends = box.messages.filter { message in
            guard case .notification(_, let params) = message,
                  let update = try? params?.decoded(as: ACPSessionUpdateParams.self),
                  case .agentMessageChunk(let content) = update.update,
                  case .text(let text, _) = content else { return false }
            return text == "完整答复"
        }
        XCTAssertEqual(fullSends.count, 1, "收尾不应重发已流式发送过的整段文本")
    }

    // MARK: - 失败回合的 stopReason

    func testFailedTurnReportsRefusal() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        // 内核回合失败：必须上报 refusal，而不是把错误伪装成 end_turn。
        runner.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: "provider exploded"))
        runner.nextOutcome = .failed("provider exploded")
        waitUntil { self.sent.contains { $0.id == .number(1) } }

        guard let response = sent.first(where: { $0.id == .number(1) }),
              case .response(_, let result) = response else {
            return XCTFail("期望响应")
        }
        let decoded = try result?.decoded(as: ACPPromptResult.self)
        XCTAssertEqual(decoded?.stopReason, .refusal)

        // 失败原因应以文本帧告知客户端，便于用户看到原因。
        XCTAssertTrue(sent.contains {
            guard case .notification(_, let params) = $0,
                  let update = try? params?.decoded(as: ACPSessionUpdateParams.self),
                  case .agentMessageChunk(let content) = update.update,
                  case .text(let text, _) = content else { return false }
            return text.contains("provider exploded")
        })
    }

    func testCancelledTurnStillReportsCancelledNotRefusal() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        // 取消即使带 errorText 也必须保持 cancelled 语义。
        runner.emit(.cancelled(conversationID: conversationID, turnID: UUID()))
        runner.nextOutcome = .cancelled
        waitUntil { self.sent.contains { $0.id == .number(1) } }

        guard let response = sent.first(where: { $0.id == .number(1) }),
              case .response(_, let result) = response else {
            return XCTFail("期望响应")
        }
        let decoded = try result?.decoded(as: ACPPromptResult.self)
        XCTAssertEqual(decoded?.stopReason, .cancelled)
    }

    // MARK: - 纯函数

    func testTextExtraction() {
        let blocks: [ContentBlock] = [
            .text("第一段"),
            .resource(EmbeddedResource(uri: "file:///a", text: "文件内容"), annotations: nil),
            .resourceLink(uri: "file:///b", name: "b", mimeType: nil, title: nil, description: nil, size: nil, annotations: nil),
            .image(mimeType: "image/png", data: "AA==", uri: nil, annotations: nil),
        ]
        XCTAssertEqual(ACPTurnCoordinator.text(from: blocks), "第一段\n\n文件内容\n\nfile:///b")
    }

    func testToolKindInference() {
        XCTAssertEqual(ACPTurnCoordinator.toolKind(for: "bash"), .execute)
        XCTAssertEqual(ACPTurnCoordinator.toolKind(for: "web_search"), .search)
        XCTAssertEqual(ACPTurnCoordinator.toolKind(for: "write_file"), .edit)
        XCTAssertEqual(ACPTurnCoordinator.toolKind(for: "read_file"), .read)
        XCTAssertEqual(ACPTurnCoordinator.toolKind(for: "think"), .think)
        XCTAssertEqual(ACPTurnCoordinator.toolKind(for: "custom_tool"), .other)
    }

    func testChoiceOptionsParsing() {
        XCTAssertEqual(
            ACPTurnCoordinator.choiceOptions(from: ["Debug", ["label": "Release"]]),
            ["Debug", "Release"]
        )
        XCTAssertEqual(ACPTurnCoordinator.choiceOptions(from: "not-an-array"), [])
    }
}
