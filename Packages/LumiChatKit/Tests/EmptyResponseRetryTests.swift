import Foundation
import LumiCoreKit
import Testing
import os
@testable import LumiChatKit

// MARK: - Empty Response Retry 集成测试
//
// 对应 docs/empty-response-handling.md §8.2（makeAssistantMessageWithEmptyRetry）
// 和 §8.3（runAgentTurn 端到端）。验证：
//   - 空响应触发自动重试
//   - nudge 消息在重试时注入
//   - 重试中的空消息不写入持久化历史
//   - 重试耗尽后注入用户可见 fallback，turn 以 .failed 结束

// MARK: - Mock Provider

/// 按预设序列依次返回响应的 mock provider。
///
/// 每次调用 `sendStreaming` 返回序列中下一个元素（循环或耗尽），
/// 用于精确控制"第几次调用返回什么"，从而验证重试逻辑。
final class SequencedResponseMockProvider: LumiLLMProvider, @unchecked Sendable {
    static let info = LumiLLMProviderInfo(
        id: "sequenced-response-mock",
        displayName: "Sequenced Response Mock",
        defaultModel: "mock",
        availableModels: ["mock"],
        websiteURL: URL(string: "https://example.com")!
    )

    /// 预设的响应序列。第 N 次调用返回第 N 个元素的闭包结果。
    private let responses: [@Sendable (LumiLLMRequest) -> LumiChatMessage]
    /// 已调用次数（async-safe 保护）。
    private let sendCount = OSAllocatedUnfairLock(initialState: 0)
    /// 每次调用收到的 request 快照，供测试断言 nudge 注入等行为。
    private let receivedRequestsLock = OSAllocatedUnfairLock(initialState: [LumiLLMRequest]())

    init(responses: [@Sendable (LumiLLMRequest) -> LumiChatMessage]) {
        self.responses = responses
    }

    /// 已发生的 `sendStreaming` 调用次数。
    var callCount: Int {
        sendCount.withLock { $0 }
    }

    /// 收到的所有 request，按调用顺序排列。
    var receivedRequests: [LumiLLMRequest] {
        receivedRequestsLock.withLock { $0 }
    }

    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    func lumiResolveAPIKey() throws -> String { "mock-key" }

    func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        let index = sendCount.withLock { state -> Int in
            let current = state
            state += 1
            return current
        }

        receivedRequestsLock.withLock { $0.append(request) }

        await onChunk(LumiStreamChunk(isDone: true, eventTitle: "结束"))

        // 超出预设序列时返回空消息，避免索引越界。
        guard index < responses.count else {
            return LumiChatMessage(
                conversationID: request.messages.last?.conversationID ?? UUID(),
                role: .assistant,
                content: ""
            )
        }
        return responses[index](request)
    }

    func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        .available
    }

    func providerStatus() -> LumiLLMProviderStatus? { nil }
}

// MARK: - Mock Tool Service

/// 能执行 `noop` 工具的最小 tool service，供 E2E 工具流程测试使用。
final class NoOpToolService: LumiToolServicing {
    var tools: [any LumiAgentTool] { [NoOpTool()] }

    func registerTools(_ tools: [any LumiAgentTool]) {}

    func tool(named name: String) -> (any LumiAgentTool)? {
        name == "noop" ? NoOpTool() : nil
    }

    func execute(_ toolCall: LumiToolCall, conversationID: UUID) async -> LumiToolResult {
        if toolCall.name == "noop",
           let data = toolCall.arguments.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: LumiJSONValue].self, from: data),
           case .string(let msg) = decoded["message"] {
            return LumiToolResult(content: "✅ \(msg)")
        }
        return LumiToolResult(content: "✅ No-op completed successfully.")
    }
}

// MARK: - makeAssistantMessageWithEmptyRetry 测试（§8.2）

@Suite(.serialized)
@MainActor
struct EmptyResponseRetrySuite {
    private func makeService(provider: SequencedResponseMockProvider) -> (ChatService, UUID) {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        let service = ChatService(configuration: .coreDatabase(directory: directory))
        let conversationID = service.createConversation(title: "EmptyRetry")
        service.registerProviders([provider])
        service.selectProvider(id: type(of: provider).info.id, model: "mock", for: conversationID)
        return (service, conversationID)
    }

    @Test("首次返回非空时不重试")
    func noRetryOnNonEmptyResponse() async throws {
        let provider = SequencedResponseMockProvider(responses: [
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "Done") }
        ])
        let (service, conversationID) = makeService(provider: provider)

        let message = try await service.makeAssistantMessageWithEmptyRetry(
            conversationID: conversationID,
            baseMessages: [
                LumiChatMessage(conversationID: conversationID, role: .user, content: "hi")
            ],
            imageAttachments: []
        )

        #expect(message.content == "Done")
        #expect(provider.callCount == 1)
    }

    @Test("首次空、第二次成功 → 重试 1 次，注入 nudge")
    func retriesOnceOnEmptyThenSucceeds() async throws {
        let provider = SequencedResponseMockProvider(responses: [
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "") },
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "Recovered") },
        ])
        let (service, conversationID) = makeService(provider: provider)

        let message = try await service.makeAssistantMessageWithEmptyRetry(
            conversationID: conversationID,
            baseMessages: [
                LumiChatMessage(conversationID: conversationID, role: .user, content: "hi")
            ],
            imageAttachments: []
        )

        #expect(message.content == "Recovered")
        #expect(!message.isEmptyResponse)
        #expect(provider.callCount == 2)

        // 第二次调用应注入 nudge（含 lumi-nudge metadata 的 system 消息）
        let secondRequest = provider.receivedRequests[1]
        #expect(secondRequest.messages.contains {
            $0.metadata["lumi-nudge"] == "empty-response-retry"
        })
    }

    @Test("连续 3 次空响应 → 重试耗尽，返回最后的空消息")
    func exhaustsRetriesOnAllEmpty() async throws {
        let provider = SequencedResponseMockProvider(responses: [
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "") },
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "   ") },
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "") },
        ])
        let (service, conversationID) = makeService(provider: provider)

        let message = try await service.makeAssistantMessageWithEmptyRetry(
            conversationID: conversationID,
            baseMessages: [
                LumiChatMessage(conversationID: conversationID, role: .user, content: "hi")
            ],
            imageAttachments: []
        )

        #expect(message.isEmptyResponse)
        #expect(provider.callCount == 3) // 1 首次 + 2 重试
    }

    @Test("重试中的空消息不写入持久化历史")
    func retryEmptyMessagesAreNotAppended() async throws {
        let provider = SequencedResponseMockProvider(responses: [
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "") },
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "OK") },
        ])
        let (service, conversationID) = makeService(provider: provider)

        _ = try await service.makeAssistantMessageWithEmptyRetry(
            conversationID: conversationID,
            baseMessages: [
                LumiChatMessage(conversationID: conversationID, role: .user, content: "hi")
            ],
            imageAttachments: []
        )

        // makeAssistantMessageWithEmptyRetry 不负责 append，验证不产生副作用。
        let messages = service.messages(for: conversationID)
        let emptyAssistants = messages.filter {
            $0.role == .assistant && $0.content.isEmpty
        }
        #expect(emptyAssistants.isEmpty)
    }

    @Test("有 toolCall 的空 content 不触发重试")
    func toolCallEmptyContentDoesNotRetry() async throws {
        let provider = SequencedResponseMockProvider(responses: [
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "",
                toolCalls: [LumiToolCall(id: "1", name: "noop", arguments: "{}")]) }
        ])
        let (service, conversationID) = makeService(provider: provider)

        let message = try await service.makeAssistantMessageWithEmptyRetry(
            conversationID: conversationID,
            baseMessages: [
                LumiChatMessage(conversationID: conversationID, role: .user, content: "hi")
            ],
            imageAttachments: []
        )

        // toolCall 存在时不算空响应，不重试。
        #expect(provider.callCount == 1)
        #expect(message.toolCalls?.isEmpty == false)
    }
}

// MARK: - runAgentTurn 端到端测试（§8.3）

@Suite(.serialized)
@MainActor
struct EmptyResponseEndToEndSuite {
    /// 构建测试用 service。
    /// - Parameter toolService: 可选的 tool service；调用方必须持有强引用，
    ///   因为 `ChatService.toolService` 是 weak（否则注册后立即释放）。
    private func makeService(
        provider: SequencedResponseMockProvider,
        toolService: LumiToolServicing? = nil
    ) -> (ChatService, UUID) {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        let service = ChatService(configuration: .coreDatabase(directory: directory))
        let conversationID = service.createConversation(title: "E2E")
        service.registerProviders([provider])
        service.selectProvider(id: type(of: provider).info.id, model: "mock", for: conversationID)
        // E2E 测试验证完整 agent loop，需要工具可用（默认 .chat 不允许工具）。
        service.setAutomationLevel(.autonomous, for: conversationID)
        if let toolService {
            service.registerToolService(toolService)
        }
        return (service, conversationID)
    }

    @Test("空响应→重试成功 → turn completed，历史只含非空消息")
    func emptyThenSuccessCompletes() async throws {
        let provider = SequencedResponseMockProvider(responses: [
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "") },
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "Done") },
        ])
        let (service, conversationID) = makeService(provider: provider)
        service.append(LumiChatMessage(conversationID: conversationID, role: .user, content: "hi"))

        let outcome = try await service.runAgentTurn(conversationID: conversationID)

        #expect(outcome == .completed)
        let messages = service.messages(for: conversationID)
        // 不应残留空 assistant 消息
        #expect(messages.contains(where: { $0.role == .assistant && $0.content.isEmpty }) == false)
        // 不应出现 error fallback
        #expect(messages.contains(where: { $0.isError }) == false)
    }

    @Test("空响应→重试耗尽 → turn failed，注入 fallback error 消息")
    func emptyExhaustedFailsWithFallback() async throws {
        let provider = SequencedResponseMockProvider(responses: [
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "") },
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "  ") },
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "") },
        ])
        let (service, conversationID) = makeService(provider: provider)
        service.append(LumiChatMessage(conversationID: conversationID, role: .user, content: "hi"))

        let outcome = try await service.runAgentTurn(conversationID: conversationID)

        #expect(outcome == .failed)
        let messages = service.messages(for: conversationID)
        // fallback error 消息应存在并带 lumi-empty-response 标记
        let fallback = messages.first { $0.metadata["lumi-empty-response"] == "true" }
        #expect(fallback != nil)
        #expect(fallback?.isError == true)
        #expect(fallback?.role == .error)
    }

    @Test("正常多轮：空 toolCall → 工具 → 非空完成")
    func normalToolFlowNotAffected() async throws {
        // 注意：本测试验证空响应重试不影响正常 tool 流程。
        // 第一轮：空 content + toolCall（不算空响应）。
        // 工具执行后第二轮：非空完成。
        let provider = SequencedResponseMockProvider(responses: [
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "",
                toolCalls: [LumiToolCall(id: "1", name: "noop", arguments: "{}")]) },
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "Task done") },
        ])
        // 必须持有强引用：ChatService.toolService 是 weak。
        let toolService = NoOpToolService()
        let (service, conversationID) = makeService(provider: provider, toolService: toolService)
        service.append(LumiChatMessage(conversationID: conversationID, role: .user, content: "hi"))

        let outcome = try await service.runAgentTurn(conversationID: conversationID)

        #expect(provider.callCount == 2)
        #expect(outcome == .completed)
    }
}
