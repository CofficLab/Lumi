import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageManager

/// `MessageManager` 的两条读取路径必须走不同的物化范围。
///
/// ## 为什么要分流
///
/// - `messagesForLLM` → LLM 回合（`LLMContextProvider.prepareContext`）。
///   只需要 `content` + `reasoningContent` + `toolCalls`。
/// - `messagesSnapshot` → UI 渲染路径。需要完整信息（`metadata`、错误详情等）。
///
/// 如果 LLM 路径也用完整读取，生产库里 `metadataJson`（35MB）与
/// `rawStreamEventsJSON`（47MB）会在每次 LLM 回合里被读取、拷贝、JSON 解码，
/// 然后永远不用。
///
/// ## 怎么验证
///
/// 用一条**带 metadata 和 rawStreamEventsJSON 的消息**作为探针：
/// 完整读取会带上它们，窄读取不会。
@MainActor
@Suite("MessageManager 读取路径的分流")
struct MessageManagerReadScopeTests {

    /// 建一个只含一条探针消息的 store。
    ///
    /// 探针带 `metadata` 与 `rawStreamEventsJSON` —— 完整读取会带上它们，
    /// 窄读取不会。
    private func makeStoreWithProbeMessage() throws -> (
        store: MessageStore,
        directory: URL,
        conversationID: UUID
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageManagerScope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try MessageStore(databaseRootURL: directory)

        let conversationID = UUID()
        let probe = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "正文内容",
            metadata: ["probe": "value"],
            reasoningContent: "推理内容",
            toolCalls: [
                MessageToolCall(id: "call-1", name: "run_command", arguments: "{}")
            ],
            rawStreamEventsJSON: "[{\"type\":\"chunk\"}]"
        )
        try store.insertMessage(probe)
        return (store, directory, conversationID)
    }

    @Test("LLM 路径不带 metadata 与原始事件流")
    func llmPathOmitsIrrelevantFields() async throws {
        let (store, directory, conversationID) = try makeStoreWithProbeMessage()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = MessageManager(store: store, dataDirectory: directory)

        let llm = await manager.messagesForLLM(in: conversationID)
        #expect(!llm.isEmpty, "LLM 路径应能读到探针消息")

        // LLM 路径：不含 metadata / rawStreamEventsJSON。
        #expect(
            llm.allSatisfy { $0.metadata.isEmpty },
            "LLM 路径不应物化 metadata"
        )
        #expect(
            llm.allSatisfy { $0.rawStreamEventsJSON == nil },
            "LLM 路径不应物化 rawStreamEventsJSON"
        )

        // 但 LLM 真正需要的字段必须保留。
        #expect(llm.allSatisfy { !$0.content.isEmpty }, "LLM 路径必须保留正文")
        #expect(
            llm.contains { !($0.toolCalls?.isEmpty ?? true) },
            "LLM 路径必须保留 toolCalls"
        )
        #expect(
            llm.contains { $0.reasoningContent != nil },
            "LLM 路径必须保留 reasoningContent"
        )
    }

    @Test("UI 路径仍拿到完整字段")
    func uiPathKeepsFullFields() async throws {
        let (store, directory, conversationID) = try makeStoreWithProbeMessage()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = MessageManager(store: store, dataDirectory: directory)

        let snapshot = await manager.messagesSnapshot(in: conversationID)
        let all = store.fetchMessages(conversationId: conversationID)

        // UI 路径不受影响：metadata 与原始事件流照常返回。
        #expect(
            all.contains { !$0.metadata.isEmpty },
            "完整读取应保留 metadata"
        )
        #expect(
            all.contains { $0.rawStreamEventsJSON != nil },
            "完整读取应保留 rawStreamEventsJSON"
        )
        #expect(
            snapshot.contains { !$0.metadata.isEmpty },
            "UI 路径应保留 metadata"
        )
        #expect(
            snapshot.contains { $0.rawStreamEventsJSON != nil },
            "UI 路径应保留 rawStreamEventsJSON"
        )
    }
}
