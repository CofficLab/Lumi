import Foundation
import LumiCoreKit
import Testing
@testable import LumiChatKit

private actor AgentTurnMockProviderState {
    var invocationCount = 0

    func nextCount() -> Int {
        invocationCount += 1
        return invocationCount
    }
}

private final class AgentTurnMockProvider: LumiLLMProvider, @unchecked Sendable {
    static let info = LumiLLMProviderInfo(
        id: "agent-turn-mock",
        displayName: "Agent Turn Mock",
        defaultModel: "mock",
        availableModels: ["mock"],
        websiteURL: URL(string: "https://example.com")!
    )

    private let state = AgentTurnMockProviderState()

    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    func lumiResolveAPIKey() throws -> String { "mock-key" }

    func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.last?.conversationID else {
            throw NSError(domain: "ToolExecutionStatusTests", code: 1)
        }

        let count = await state.nextCount()

        if count == 1 {
            return LumiChatMessage(
                conversationID: conversationID,
                role: .assistant,
                content: "",
                toolCalls: [
                    LumiToolCall(id: "slow-call", name: "slow_tool", arguments: "{}")
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
}

@MainActor
private final class SlowToolService: LumiToolServicing {
    private(set) var executeCount = 0
    var tools: [any LumiAgentTool] { [] }

    func registerTools(_ tools: [any LumiAgentTool]) throws {}

    func tool(named name: String) -> (any LumiAgentTool)? { nil }

    func execute(_ toolCall: LumiToolCall, conversationID: UUID) async -> LumiToolResult {
        executeCount += 1
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        return LumiToolResult(content: "slow ok", duration: 1.2)
    }
}

enum ToolExecutionStatusTestsSupport {
    static func elapsedSeconds(in status: String) -> Int? {
        guard let open = status.firstIndex(of: "（"),
              let suffix = status[open...].firstIndex(of: "s")
        else {
            return nil
        }

        let numberStart = status.index(after: open)
        return Int(status[numberStart..<suffix])
    }
}

@MainActor
@Test func toolExecutionUpdatesElapsedSecondsInTransientStatus() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LumiChatKitToolStatus-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let service = try ChatService(configuration: .coreDatabase(directory: directory))
    let conversationID = service.createConversation(title: "Tool Progress")
    service.setAutomationLevel(.autonomous, for: conversationID)
    service.registerProviders([AgentTurnMockProvider()])
    service.selectProvider(
        id: AgentTurnMockProvider.info.id,
        model: "mock",
        for: conversationID
    )

    let slowTools = SlowToolService()
    service.registerToolService(slowTools)

    service.append(
        LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: "run slow tool"
        )
    )

    let turnTask = Task { @MainActor in
        _ = try await service.runAgentTurn(conversationID: conversationID)
    }

    var sawNonZeroElapsed = false
    let deadline = Date().addingTimeInterval(3)
    while Date() < deadline {
        if let content = service.transientStatusMessage(for: conversationID)?.content,
           let elapsed = ToolExecutionStatusTestsSupport.elapsedSeconds(in: content),
           elapsed >= 1 {
            sawNonZeroElapsed = true
            break
        }
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    _ = try await turnTask.value

    #expect(sawNonZeroElapsed)
    #expect(slowTools.executeCount == 1)
}
