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

    private var runner: MockTurnRunner!
    private var store: MockMessageStore!
    private var sessions: ACPSessionManager!
    private var box: SentBox!
    private var coordinator: ACPTurnCoordinator!

    override func setUp() {
        super.setUp()
        runner = MockTurnRunner()
        store = MockMessageStore()
        sessions = ACPSessionManager(conversationFactory: MockConversationFactory())
        box = SentBox()
        coordinator = ACPTurnCoordinator(
            agentLoop: runner,
            messages: store,
            sessions: sessions,
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

        // 回合完成：写 assistant 消息后发事件 + runTurn 返回 .completed。
        store.messagesByConversation[conversationID, default: []].append(
            Message(conversationID: conversationID, role: .assistant, content: "已修复")
        )
        runner.emit(.completed(conversationID: conversationID, turnID: UUID()))
        runner.nextOutcome = .completed
        waitUntil { self.sent.contains { $0.id == .number(1) } }

        let response = sent.first { $0.id == .number(1) }
        guard case .response(_, let result) = response else {
            return XCTFail("期望最终响应")
        }
        let decoded = try result?.decoded(as: ACPPromptResult.self)
        XCTAssertEqual(decoded?.stopReason, .endTurn)

        // 文本通知。
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
        // 等双路径都跑完
        waitUntil { self.runner.runCalls.count >= 1 && self.sent.filter { $0.id == .number(1) }.count >= 1 }

        let responses = sent.filter { $0.id == .number(1) }
        XCTAssertEqual(responses.count, 1)
    }

    // MARK: - 工具调用

    func testToolCallsReceivedEmitsToolCallNotification() throws {
        let sessionID = try makeSessionID()
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = coordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hi")])
        waitUntil { self.runner.runCalls.contains(conversationID) }

        let call = MessageToolCall(id: "call_001", name: "bash", arguments: #"{"cmd":"ls"}"#)
        runner.emit(.toolCallsReceived(
            conversationID: conversationID,
            turnID: UUID(),
            assistantMessageID: UUID(),
            toolCalls: [call]
        ))

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

        // assistant 消息带工具调用与结果。
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

    // MARK: - 挂起与权限

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

        waitUntil { self.sent.contains { $0.method == ACPMethod.sessionRequestPermission } }
        guard let permissionRequest = sent.first(where: { $0.method == ACPMethod.sessionRequestPermission }),
              case .request(let id, _, let params) = permissionRequest else {
            return XCTFail("期望 request_permission 请求")
        }
        let decoded = try params?.decoded(as: ACPRequestPermissionParams.self)
        XCTAssertEqual(decoded?.options.map(\.name), ["是", "否"])

        // 用户选"是" → resume。
        coordinator.handlePermissionResponse(
            id: id,
            result: try? JSONValue.stringify(ACPRequestPermissionResult(outcome: .selected(optionId: "是")))
        )
        waitUntil { self.runner.resumeCalls.count == 1 }
        XCTAssertEqual(runner.resumeCalls.first?.suspensionID, "userInput:call_001")
        XCTAssertEqual(runner.resumeCalls.first?.answer, "是")
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

        waitUntil { self.sent.contains { $0.method == ACPMethod.sessionRequestPermission } }
        guard let permissionRequest = sent.first(where: { $0.method == ACPMethod.sessionRequestPermission }),
              case .request(_, _, let params) = permissionRequest else {
            return XCTFail("期望 request_permission 请求")
        }
        let decoded = try params?.decoded(as: ACPRequestPermissionParams.self)
        XCTAssertEqual(decoded?.options.map(\.name), ["Debug", "Release"])
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
        XCTAssertTrue(runner.cancelCalls.contains(conversationID))
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
        // image 块无文本 → 提示内容为空 → 拒绝。
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
            onSend: { [box] message in box.messages.append(message) },
            turnStartTimeout: 0.5
        )
        let sessionID = try sessions.createSession(cwd: "/tmp/wd")
        _ = shortCoordinator.startTurn(
            sessionID: sessionID,
            requestID: .number(1),
            prompt: [.text("hello")]
        )
        // 不注入任何事件：watchdog 应在 0.5s 后按失败收尾。
        waitUntil({ box.messages.contains { $0.id == .number(1) } }, timeout: 3.0)
        guard let response = box.messages.first(where: { $0.id == .number(1) }),
              case .response(_, let result) = response else {
            return XCTFail("期望 watchdog 超时响应")
        }
        let decoded = try result?.decoded(as: ACPPromptResult.self)
        XCTAssertEqual(decoded?.stopReason, .endTurn)
        // 超时文本通知。
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
            onSend: { [box] message in box.messages.append(message) },
            turnStartTimeout: 0.5
        )
        let sessionID = try sessions.createSession(cwd: "/tmp/wd2")
        let conversationID = try XCTUnwrap(sessions.conversationID(for: sessionID))
        _ = shortCoordinator.startTurn(sessionID: sessionID, requestID: .number(1), prompt: [.text("hello")])
        waitUntil { runner.runCalls.count == 1 }
        // 事件到达即视为进展：watchdog 不应再触发。
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
        // 应来自 completed（end_turn），而非超时文本。
        guard let response = responses.first, case .response(_, let result) = response else {
            return XCTFail("期望响应")
        }
        let decoded = try result?.decoded(as: ACPPromptResult.self)
        XCTAssertEqual(decoded?.stopReason, .endTurn)
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
