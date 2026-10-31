import Foundation
import KitAgentTool
import Testing
@testable import PluginConversationNew

@Suite("NewConversationRowRenderer")
@MainActor
struct NewConversationRowRendererTests {

    private func toolCall(
        name: String = CreateNewConversationTool.toolName,
        content: String? = nil
    ) -> ToolCall {
        ToolCall(
            id: UUID().uuidString,
            name: name,
            arguments: "{}",
            result: content.map { ToolCallResult(content: $0) }
        )
    }

    private func payload(_ starter: String = "Do the unrelated task") -> String {
        let suggestion = NewConversationSuggestion(
            conversationID: UUID(),
            title: "Standalone topic",
            starter: starter
        )
        return "## New Conversation Prepared\n\n```json\n" +
            (String(data: (try? JSONEncoder().encode(suggestion)) ?? Data(), encoding: .utf8) ?? "") +
            "\n```"
    }

    // MARK: - canRender

    @Test("命中本工具且 payload 可解析时渲染")
    func canRenderMatchesToolWithPayload() {
        let renderer = NewConversationRowRenderer()
        #expect(renderer.canRender(toolCall: toolCall(content: payload())))
    }

    @Test("工具名不匹配时不渲染")
    func canRenderRejectsOtherTools() {
        let renderer = NewConversationRowRenderer()
        #expect(!renderer.canRender(toolCall: toolCall(name: "git_log", content: payload())))
    }

    @Test("结果缺失或 payload 损坏时不渲染")
    func canRenderRejectsUndecodableResults() {
        let renderer = NewConversationRowRenderer()
        #expect(!renderer.canRender(toolCall: toolCall(content: nil)))
        #expect(!renderer.canRender(toolCall: toolCall(content: "plain text without payload")))
        #expect(!renderer.canRender(toolCall: toolCall(content: "```json\n{ not json\n```")))
        #expect(!renderer.canRender(toolCall: toolCall(content: "```json\n```")))
    }

    // MARK: - JSON 提取

    @Test(
        "提取首个 json 代码块",
        arguments: [
            ("```json\n{\"a\":1}\n```", "{\"a\":1}"),
            ("前文\n```json\n{\"a\":1}\n```\n后文", "{\"a\":1}"),
            ("```json\n```", ""),
            ("没有代码块", ""),
        ]
    )
    func extractJSONHandlesEdgeCases(content: String, expected: String) {
        let extracted = NewConversationRowRenderer.extractJSON(from: content)
        if expected.isEmpty {
            #expect(extracted == nil)
        } else {
            #expect(extracted == expected)
        }
    }

    // MARK: - 解码

    @Test("解码保留 starter 与标题")
    func decodeSuggestionRoundTrips() throws {
        let suggestion = try #require(
            NewConversationRowRenderer.decodeSuggestion(from: payload("Investigate the CI flake"))
        )
        #expect(suggestion.title == "Standalone topic")
        #expect(suggestion.starter == "Investigate the CI flake")
    }

    @Test("渲染优先级高于默认工具卡片")
    func priorityIsAboveDefault() {
        #expect(NewConversationRowRenderer.priority > 100)
        #expect(!NewConversationRowRenderer.id.isEmpty)
    }
}
