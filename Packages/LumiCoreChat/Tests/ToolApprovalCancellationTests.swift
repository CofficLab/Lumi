import Foundation
import LumiCoreKit
import Testing
@testable import LumiChatKit

// 审计项 3.2 的回归测试：`toolApprovalContinuation` 在取消时泄漏 / 死锁。
//
// 背景：审批用的是 `withCheckedContinuation`（非 throwing 版本），不响应 task
// cancellation。若 `cancelSending` 只取消 task 而不 resume continuation，
// `await requestToolApproval` 会永久挂起 → turn 死锁、状态泄漏、甚至取消后仍执行工具。
// 这里验证三条路径：cancel 解除挂起、resume-once 不退化、跨会话 cancel 不误伤。

// MARK: - Mocks

private actor ApprovalMockProviderState {
    var invocationCount = 0

    func nextCount() -> Int {
        invocationCount += 1
        return invocationCount
    }
}

private final class ApprovalMockProvider: LumiLLMProvider, @unchecked Sendable {
    static let info = LumiLLMProviderInfo(
        id: "approval-mock",
        displayName: "Approval Mock",
        defaultModel: "mock",
        availableModels: ["mock"],
        websiteURL: URL(string: "https://example.com")!
    )

    private let state = ApprovalMockProviderState()

    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    func lumiResolveAPIKey() throws -> String { "mock-key" }
    func hasApiKey() -> Bool { true }
    func getApiKey() -> String { "mock-key" }
    func setApiKey(_ apiKey: String) {}
    func removeApiKey() {}

    func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.last?.conversationID else {
            throw NSError(domain: "ToolApprovalCancellationTests", code: 1)
        }

        let count = await state.nextCount()

        // 首轮让 LLM 提出一个高危工具调用，触发 .build 模式下的审批流程。
        if count == 1 {
            return LumiChatMessage(
                conversationID: conversationID,
                role: .assistant,
                content: "",
                toolCalls: [
                    LumiToolCall(id: "risky-call", name: "risky_tool", arguments: "{}")
                ]
            )
        }

        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "done"
        )
    }

    func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        .available
    }

    func providerStatus() -> LumiLLMProviderStatus? {
        nil
    }

    func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        .nonRetryable
    }

    func errorRenderKind(for error: Error) -> String? { nil }

    func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage {
        LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: error.localizedDescription,
            isError: true
        )
    }
}

/// 首轮提出携带指定 arguments 的工具调用，用于测试不同参数形态（如半截 JSON）。
private final class FixedArgumentsMockProvider: LumiLLMProvider, @unchecked Sendable {
    static let info = LumiLLMProviderInfo(
        id: "fixed-args-mock",
        displayName: "Fixed Args Mock",
        defaultModel: "mock",
        availableModels: ["mock"],
        websiteURL: URL(string: "https://example.com")!
    )

    private let toolCallArguments: String
    private var didEmitToolCall = false

    init(toolCallArguments: String) {
        self.toolCallArguments = toolCallArguments
    }

    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    func lumiResolveAPIKey() throws -> String { "mock-key" }
    func hasApiKey() -> Bool { true }
    func getApiKey() -> String { "mock-key" }
    func setApiKey(_ apiKey: String) {}
    func removeApiKey() {}

    func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.last?.conversationID else {
            throw NSError(domain: "ToolApprovalCancellationTests", code: 1)
        }

        if !didEmitToolCall {
            didEmitToolCall = true
            return LumiChatMessage(
                conversationID: conversationID,
                role: .assistant,
                content: "",
                toolCalls: [
                    LumiToolCall(id: "risky-call", name: "risky_tool", arguments: toolCallArguments)
                ]
            )
        }

        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "done"
        )
    }

    func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        .available
    }

    func providerStatus() -> LumiLLMProviderStatus? {
        nil
    }

    func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        .nonRetryable
    }

    func errorRenderKind(for error: Error) -> String? { nil }

    func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage {
        LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: error.localizedDescription,
            isError: true
        )
    }
}

/// 永远返回 `.high` 风险等级的工具，用于触发 `.build` 模式下的审批弹窗。
private struct HighRiskMockTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "risky_tool",
        displayName: "Risky Tool",
        description: "A mock tool that always requires approval"
    )

    var inputSchema: LumiJSONValue { .object([:]) }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        "risky ok"
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .high
    }
}

@MainActor
private final class HighRiskToolService: LumiToolServicing {
    private(set) var executeCount = 0
    private let tool = HighRiskMockTool()
    var tools: [any LumiAgentTool] { [tool] }

    func registerTools(_ tools: [any LumiAgentTool]) throws {}

    func tool(named name: String) -> (any LumiAgentTool)? {
        name == HighRiskMockTool.info.id ? tool : nil
    }

    func execute(_ toolCall: LumiToolCall, conversationID: UUID) async -> LumiToolResult {
        executeCount += 1
        return LumiToolResult(content: "risky ok", duration: 0.01)
    }
}

// MARK: - Helpers

@MainActor
private func makeService() throws -> (ChatService, UUID, HighRiskToolService) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LumiChatKitToolApproval-\(UUID().uuidString)", isDirectory: true)

    let service = try ChatService(configuration: .coreDatabase(directory: directory), agentToolComponent: AgentToolComponent())
    let conversationID = service.createConversation(title: "Approval Cancel")
    // 关键：.build 模式才会触发高危工具的审批弹窗（.autonomous 会跳过审批直接执行）。
    service.setAutomationLevel(.build, for: conversationID)
    service.registerProviders([ApprovalMockProvider()])
    service.selectProvider(
        id: ApprovalMockProvider.info.id,
        model: "mock",
        for: conversationID
    )
    let toolService = HighRiskToolService()

    service.append(
        LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: "run risky tool"
        )
    )
    return (service, conversationID, toolService)
}

/// 轮询直到审批弹窗挂起（`pendingToolConfirmation != nil`），最多等待 `seconds` 秒。
/// 返回 false 表示超时——通常意味着 turn 未走到审批这一步，测试本身有问题。
@MainActor
private func waitForApprovalPending(
    in service: ChatService,
    timeoutSeconds: Double = 3
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
        if service.pendingToolConfirmation != nil { return true }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return false
}

// MARK: - Tests

@MainActor
@Test func cancelDuringToolApprovalResumesContinuationAndDoesNotDeadlock() async throws {
    let (service, conversationID, toolService) = try makeService()

    // 启动 turn，它会在 requestToolApproval 处挂起，等待用户审批。
    let turnTask = Task { @MainActor in
        _ = try? await service.runAgentTurn(conversationID: conversationID, toolService: toolService)
    }

    let pending = await waitForApprovalPending(in: service)
    #expect(pending, "turn 应在审批弹窗处挂起")
    #expect(service.toolApprovalContinuation != nil)
    #expect(service.pendingToolConfirmation != nil)

    // 关键动作：取消该会话。修复前 continuation 不会被 resume → await 永久挂起 → turn 死锁。
    service.cancelSending(for: conversationID)

    // 审批状态应被立即清空（continuation 已 resume，弹窗已消失）。
    #expect(service.toolApprovalContinuation == nil)
    #expect(service.pendingToolConfirmation == nil)

    // turn 必须在合理时间内终止——这是「不死锁」的直接断言。
    // 若死锁，await turnTask.value 会一直挂起，测试框架会超时失败。
    await turnTask.value

    // 高危工具不应被执行（取消即拒绝）。
    #expect(toolService.executeCount == 0, "取消后不应执行被拒绝的工具")
}

@MainActor
@Test func resumingApprovalTwiceIsSafe() async throws {
    let (service, conversationID, toolService) = try makeService()

    let turnTask = Task { @MainActor in
        _ = try? await service.runAgentTurn(conversationID: conversationID, toolService: toolService)
    }

    let pending = await waitForApprovalPending(in: service)
    #expect(pending, "turn 应在审批弹窗处挂起")
    #expect(service.toolApprovalContinuation != nil)

    // 第一次 resume：合法。
    service.approvePendingTool()
    #expect(service.toolApprovalContinuation == nil)

    // 第二次 resume：必须是无害的 no-op，不能触发
    // "Continuation was resumed more than once" 的 fatalError。
    // （UI 上连按 / 弹窗 dismiss 与按钮点击并发时会出现这种情况。）
    service.approvePendingTool()
    service.rejectPendingTool()

    #expect(service.toolApprovalContinuation == nil)
    #expect(service.pendingToolConfirmation == nil)

    await turnTask.value
}

@MainActor
@Test func cancellingUnrelatedConversationDoesNotDisturbPendingApproval() async throws {
    let (service, conversationA, toolService) = try makeService()

    // 第二个会话，用于触发一次「无关的」cancel。
    let conversationB = service.createConversation(title: "Unrelated")
    service.setAutomationLevel(.build, for: conversationB)
    service.selectProvider(
        id: ApprovalMockProvider.info.id,
        model: "mock",
        for: conversationB
    )

    let turnTask = Task { @MainActor in
        _ = try? await service.runAgentTurn(conversationID: conversationA, toolService: toolService)
    }

    let pending = await waitForApprovalPending(in: service)
    #expect(pending, "会话 A 应在审批弹窗处挂起")
    let pendingConfirmation = service.pendingToolConfirmation
    #expect(pendingConfirmation?.conversationID == conversationA)

    // 取消会话 B——不应误伤会话 A 挂起的审批。
    service.cancelSending(for: conversationB)

    #expect(service.pendingToolConfirmation == pendingConfirmation,
            "会话 A 的审批应保持原样，不被会话 B 的取消波及")
    #expect(service.toolApprovalContinuation != nil,
            "会话 A 的 continuation 不应被 resume")

    // 清理：手动结束会话 A 挂起的 turn，避免测试泄漏到下一个用例。
    service.cancelSending(for: conversationA)
    await turnTask.value
}

@MainActor
@Test func truncatedToolCallArgumentsStillTriggerApprovalDialog() async throws {
    // 审计 4.2：LLM 流被截断时 toolCall.arguments 可能是半截 JSON。
    // 修复前，decode 失败导致整个审批 if 被跳过 → 高危工具被静默执行（审批弹窗不出现）。
    // 修复后，decode 失败用空字典兜底，riskLevel 仍被求值 → 弹窗正常出现。
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LumiChatKitToolApprovalTrunc-\(UUID().uuidString)", isDirectory: true)

    let service = try ChatService(configuration: .coreDatabase(directory: directory), agentToolComponent: AgentToolComponent())
    let conversationID = service.createConversation(title: "Truncated Args")
    service.setAutomationLevel(.build, for: conversationID)
    // 模拟流被截断：arguments 是半截 JSON，JSONDecoder 会抛错。
    service.registerProviders([
        FixedArgumentsMockProvider(toolCallArguments: "{\"path\":\"/Users/ang")
    ])
    service.selectProvider(
        id: FixedArgumentsMockProvider.info.id,
        model: "mock",
        for: conversationID
    )
    let toolService = HighRiskToolService()

    service.append(
        LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: "run risky tool"
        )
    )

    let turnTask = Task { @MainActor in
        _ = try? await service.runAgentTurn(conversationID: conversationID, toolService: toolService)
    }

    // 关键断言：即便 arguments 是半截 JSON，审批弹窗仍应出现。
    let pending = await waitForApprovalPending(in: service)
    #expect(pending, "半截 JSON 不应绕过审批——riskLevel 仍须被求值")

    // 清理：同意执行，让 turn 正常结束。
    service.approvePendingTool()
    await turnTask.value
}
