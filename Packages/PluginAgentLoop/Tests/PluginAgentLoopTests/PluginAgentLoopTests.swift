import Testing
import Foundation
import KitLLM
@testable import PluginAgentLoop
import ProviderMessage

@MainActor
@Test func testPluginInitialization() async throws {
    let plugin = PluginAgentLoop()
    #expect(plugin.id == "com.coffic.lumi.plugin.agent-loop")
    #expect(plugin.order == 8)
}

@MainActor
@Test func testPluginMetadata() async throws {
    let plugin = PluginAgentLoop()
    let metadata = plugin.metadata
    #expect(metadata.name == "Plugin Agent Loop")
    #expect(metadata.category == .core)
}

@Test("willSendToLLM message restoration preserves assistant tool calls")
func testMessageFromLLMMessagePreservesToolCalls() {
    let conversationID = UUID()
    let message = LLMMessage(
        role: .assistant,
        content: "",
        toolCalls: [
            LLMToolCall(id: "tool-1", name: "run_command", arguments: "{\"command\":\"git status\"}")
        ],
        reasoningContent: "先检查状态"
    )

    let restored = messageFromLLMMessage(message, conversationID: conversationID)

    #expect(restored.conversationID == conversationID)
    #expect(restored.toolCalls == [
        MessageToolCall(id: "tool-1", name: "run_command", arguments: "{\"command\":\"git status\"}")
    ])
    #expect(restored.reasoningContent == "先检查状态")
}
