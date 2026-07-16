import XCTest
@testable import LLMKit

final class CoreModelsTests: XCTestCase {
    func testModelCatalogItemStoresSpecAndCapabilities() {
        let item = LLMModelCatalogItem(
            id: "gpt-4o",
            description: "OpenAI 旗舰多模态模型，支持视觉和工具调用",
            spec: LLMModelSpec(
                contextWindowSize: 128_000,
                supportsVision: true,
                supportsTools: true
            )
        )

        XCTAssertEqual(item.id, "gpt-4o")
        XCTAssertEqual(item.spec.contextWindowSize, 128_000)
        XCTAssertEqual(item.spec.capabilities, LLMModelCapabilities(supportsVision: true, supportsTools: true))
    }

    func testToolCallStoresValues() {
        let toolCall = ToolCall(
            id: "call_123",
            name: "read_file",
            arguments: #"{"path":"README.md"}"#
        )

        XCTAssertEqual(toolCall.id, "call_123")
        XCTAssertEqual(toolCall.name, "read_file")
        XCTAssertEqual(toolCall.arguments, #"{"path":"README.md"}"#)
    }

    func testChatMessageDefaultIDAndOptionalToolFields() {
        let message = ChatMessage(role: .assistant, content: "Hello")

        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "Hello")
        XCTAssertNil(message.toolCalls)
        XCTAssertNil(message.toolCallID)
        XCTAssertNotNil(UUID(uuidString: message.id.uuidString))
    }

    func testChatMessageStoresExplicitToolFields() {
        let id = UUID()
        let toolCall = ToolCall(id: "call_123", name: "read_file", arguments: "{}")
        let message = ChatMessage(
            id: id,
            role: .assistant,
            content: "",
            toolCalls: [toolCall],
            toolCallID: "tool_result_123"
        )

        XCTAssertEqual(message.id, id)
        XCTAssertEqual(message.toolCalls, [toolCall])
        XCTAssertEqual(message.toolCallID, "tool_result_123")
    }

    func testStreamChunkStoresAllFields() {
        let toolCall = ToolCall(id: "call_123", name: "read_file", arguments: "{}")
        let chunk = StreamChunk(
            content: "Hello",
            isDone: true,
            toolCalls: [toolCall],
            error: "error",
            partialJson: "{}",
            eventType: .contentBlockDelta,
            rawEvent: "event",
            rawStreamPayload: "payload",
            inputTokens: 1,
            outputTokens: 2,
            stopReason: "stop"
        )

        XCTAssertEqual(chunk.content, "Hello")
        XCTAssertTrue(chunk.isDone)
        XCTAssertEqual(chunk.toolCalls, [toolCall])
        XCTAssertEqual(chunk.error, "error")
        XCTAssertEqual(chunk.partialJson, "{}")
        XCTAssertEqual(chunk.eventType, .contentBlockDelta)
        XCTAssertEqual(chunk.rawEvent, "event")
        XCTAssertEqual(chunk.rawStreamPayload, "payload")
        XCTAssertEqual(chunk.inputTokens, 1)
        XCTAssertEqual(chunk.outputTokens, 2)
        XCTAssertEqual(chunk.stopReason, "stop")
    }

    func testStreamChunkWithRawStreamPayloadPreservesExistingFields() {
        let chunk = StreamChunk(
            content: "Hello",
            eventType: .textDelta,
            inputTokens: 3,
            outputTokens: 5
        )

        let updated = chunk.withRawStreamPayload("raw")

        XCTAssertEqual(updated.content, "Hello")
        XCTAssertEqual(updated.eventType, .textDelta)
        XCTAssertEqual(updated.inputTokens, 3)
        XCTAssertEqual(updated.outputTokens, 5)
        XCTAssertEqual(updated.rawStreamPayload, "raw")
    }

    func testProviderErrorDescriptions() {
        XCTAssertEqual(OpenAICompatibleProviderError.noChoices.errorDescription, "No choices in response")
        XCTAssertEqual(
            OpenAICompatibleProviderError.apiError(message: "Invalid API key").errorDescription,
            "Invalid API key"
        )
    }
}
