import Foundation
import ProviderMessage
import Testing
@testable import PluginConversationExport

/// HTML 导出的工具结果去重（回归 #580）。
///
/// 生产消息流会把同一条完成的工具结果既写进助手消息的嵌套 `toolCalls`，
/// 又写一条独立的 `.tool` 消息（见 AgentLoopProvider+Tool / +Message）。
/// debug 导出必须按 `toolCallID` 去重：已被嵌套结果覆盖的独立 `.tool`
/// 消息不再重复渲染；未被覆盖的独立结果仍须保留。
@MainActor
struct ConversationExportToolDedupTests {

    private func makeSnapshot(_ messages: [Message]) -> ConversationExportSnapshot {
        ConversationExportSnapshot(
            conversationID: UUID(),
            title: "Dedup",
            createdAt: nil,
            projectPath: nil,
            providerID: nil,
            modelName: nil,
            language: nil,
            messages: messages,
            exportedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func exportHTML(_ messages: [Message]) throws -> String {
        let result = ConversationHTMLExporter.export(makeSnapshot(messages))
        return try #require(String(data: result.data, encoding: .utf8))
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    private func assistantCall(
        _ cid: UUID,
        id: String,
        resultContent: String?,
        at time: TimeInterval
    ) -> Message {
        let result = resultContent.map { MessageToolResult(content: $0) }
        let call = MessageToolCall(id: id, name: "read_file", arguments: "{}", result: result)
        return Message(
            conversationID: cid,
            role: .assistant,
            content: "",
            createdAt: Date(timeIntervalSince1970: time),
            toolCalls: [call]
        )
    }

    private func standaloneTool(
        _ cid: UUID,
        toolCallID: String?,
        content: String,
        at time: TimeInterval
    ) -> Message {
        Message(
            conversationID: cid,
            role: .tool,
            content: content,
            createdAt: Date(timeIntervalSince1970: time),
            toolCallID: toolCallID
        )
    }

    @Test("嵌套结果与独立 .tool 消息同源时只渲染一次（回归 #580）")
    func duplicateToolResultRenderedOnce() throws {
        let cid = UUID()
        let messages = [
            assistantCall(cid, id: "call-1", resultContent: "TOOL_RESULT_MARKER", at: 10),
            standaloneTool(cid, toolCallID: "call-1", content: "TOOL_RESULT_MARKER", at: 11),
        ]

        let html = try exportHTML(messages)

        #expect(occurrences(of: "TOOL_RESULT_MARKER", in: html) == 1)
        #expect(html.contains("Tool calls (1)"))
        // 去重后只剩助手消息一条。
        #expect(html.contains("1 messages"))
    }

    @Test("未被嵌套结果覆盖的独立 .tool 消息仍照常渲染")
    func uncoveredStandaloneToolMessageStillRendered() throws {
        let cid = UUID()
        let messages = [
            assistantCall(cid, id: "call-1", resultContent: "NESTED_OUTPUT", at: 10),
            standaloneTool(cid, toolCallID: "call-orphan", content: "ORPHAN_OUTPUT", at: 11),
        ]

        let html = try exportHTML(messages)

        #expect(html.contains("NESTED_OUTPUT"))
        #expect(html.contains("ORPHAN_OUTPUT"))
        #expect(html.contains("2 messages"))
    }

    @Test("没有 toolCallID 的独立 .tool 消息无法关联，仍照常渲染")
    func standaloneToolMessageWithoutToolCallIDStillRendered() throws {
        let cid = UUID()
        let messages = [
            assistantCall(cid, id: "call-1", resultContent: "NESTED_OUTPUT", at: 10),
            standaloneTool(cid, toolCallID: nil, content: "NO_ID_OUTPUT", at: 11),
        ]

        let html = try exportHTML(messages)

        #expect(html.contains("NO_ID_OUTPUT"))
        #expect(html.contains("2 messages"))
    }

    @Test("嵌套调用尚无结果（pending）时不抑制同 ID 的独立 .tool 消息")
    func pendingNestedCallDoesNotSuppressStandalone() throws {
        let cid = UUID()
        let messages = [
            assistantCall(cid, id: "call-1", resultContent: nil, at: 10),
            standaloneTool(cid, toolCallID: "call-1", content: "PENDING_STANDALONE", at: 11),
        ]

        let html = try exportHTML(messages)

        #expect(html.contains("PENDING_STANDALONE"))
        #expect(html.contains("2 messages"))
    }

    @Test("多条工具结果各自按 toolCallID 去重，孤儿结果保留")
    func multipleToolResultsDedupedIndependently() throws {
        let cid = UUID()
        let callA = MessageToolCall(id: "call-a", name: "read_file", arguments: "{}", result: MessageToolResult(content: "MARKER_A"))
        let callB = MessageToolCall(id: "call-b", name: "read_file", arguments: "{}", result: MessageToolResult(content: "MARKER_B"))
        let assistant = Message(
            conversationID: cid,
            role: .assistant,
            content: "",
            createdAt: Date(timeIntervalSince1970: 10),
            toolCalls: [callA, callB]
        )
        let messages = [
            assistant,
            standaloneTool(cid, toolCallID: "call-a", content: "MARKER_A", at: 11),
            standaloneTool(cid, toolCallID: "call-b", content: "MARKER_B", at: 12),
            standaloneTool(cid, toolCallID: "call-c", content: "MARKER_C", at: 13),
        ]

        let html = try exportHTML(messages)

        #expect(occurrences(of: "MARKER_A", in: html) == 1)
        #expect(occurrences(of: "MARKER_B", in: html) == 1)
        #expect(html.contains("MARKER_C"))
        // 助手 + 孤儿 .tool 共两条。
        #expect(html.contains("2 messages"))
    }
}