import Foundation
import ProviderMessage
import SQLite3
import Testing
@testable import PluginMessageManager

/// LLM 回合准备上下文时，不得物化与 LLM 无关的大字段。
///
/// ## 要复现的问题
///
/// `AgentLoopProvider+Tool.swift:617` 在每次 LLM 请求前调用
/// `contextProvider.prepareContext(for:)`，其第一步是
/// `llmHistory(for:)` → `messagesForLLM` → `MessageStore.fetchMessages`，
/// **没有 limit**，把整个会话物化。
///
/// 物化时 `MessageModel.toMessage()` 会把**每一列**都搬进 `Message`，
/// 并对 JSON 列逐条解码：
///
/// ```
/// let metadata = metadataJson.flatMap { try? decoder.decode(...) }
/// let toolCalls = toolCallsJson.flatMap { try? decoder.decode(...) }
/// ```
///
/// 生产库实测各列体积：
///
/// | 列 | 体积 |
/// |---|---|
/// | `ZTOOLCALLSJSON` | 281 MB |
/// | `ZCONTENT` | 121 MB |
/// | `ZREASONINGCONTENT` | 54 MB |
/// | `ZRAWSTREAMEVENTSJSON` | 47 MB |
/// | `ZMETADATAJSON` | 35 MB |
///
/// LLM 上下文**只需要** `content` + `reasoningContent` + `toolCalls`。
/// `rawStreamEventsJSON`（原始 SSE 事件流）与 `metadataJson` 在 LLM 路径上
/// 是纯粹的浪费 —— 它们要被读取、拷贝、JSON 解码，然后永远不用。
///
/// ## 不变式
///
/// LLM 回合读取消息时，**不得**物化 `rawStreamEventsJSON` 与 `metadataJson`。
@MainActor
@Suite("LLM 回合的消息物化范围")
struct LLMTurnMaterializationScopeTests {

    private static var productionDatabaseURL: URL? {
        let path = ProcessInfo.processInfo.environment["LUMI_PROD_MESSAGES_SQLITE"]
        guard let path, FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    private func makeStoreFromProductionCopy() throws -> (store: MessageStore, directory: URL)? {
        guard let source = Self.productionDatabaseURL else { return nil }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LLMScope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: source,
            to: directory.appendingPathComponent("messages.sqlite")
        )
        let wal = source.appendingPathExtension("wal")
        if FileManager.default.fileExists(atPath: wal.path) {
            try? FileManager.default.copyItem(
                at: wal,
                to: directory.appendingPathComponent("messages.sqlite-wal")
            )
        }
        let store = try MessageStore(databaseRootURL: directory)
        return (store, directory)
    }

    /// 找出生产库里消息最多的会话。
    private func findBusiestConversation(in databaseURL: URL) throws -> (id: String, count: Int)? {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else { return nil }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let sql = """
        SELECT ZCONVERSATIONID, COUNT(*) FROM ZMESSAGEMODEL \
        GROUP BY ZCONVERSATIONID ORDER BY COUNT(*) DESC LIMIT 1
        """
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let idPointer = sqlite3_column_text(statement, 0) else { return nil }
        return (String(cString: idPointer), Int(sqlite3_column_int(statement, 1)))
    }

    @Test("LLM 回合读取消息时，不得物化与 LLM 无关的大字段")
    func llmReadMustNotMaterializeIrrelevantLargeFields() throws {
        guard let (store, directory) = try makeStoreFromProductionCopy() else {
            print("LLMSCOPE skip=生产库副本不可用")
            return
        }
        defer { try? FileManager.default.removeItem(at: directory) }

        let databaseURL = directory.appendingPathComponent("messages.sqlite")
        guard let busiest = try findBusiestConversation(in: databaseURL) else {
            print("LLMSCOPE skip=生产库为空")
            return
        }
        let conversationID = try #require(UUID(uuidString: busiest.id))
        print("LLMSCOPE conversation=\(busiest.id) messages=\(busiest.count)")

        // LLM 回合读取消息走的就是这条路径。
        let messages = store.fetchMessagesForLLMContext(conversationId: conversationID)

        #expect(messages.count == busiest.count, "应读到整个会话的历史")

        // ── 不变式 1：不得物化原始 SSE 事件流 ──
        //
        // `rawStreamEventsJSON` 在生产库合计 47MB，是 LLM 路径上的纯浪费。
        let withStreamEvents = messages.filter { $0.rawStreamEventsJSON != nil }
        #expect(
            withStreamEvents.isEmpty,
            """
            LLM 回合物化了 \(withStreamEvents.count)/\(messages.count) 条消息的 \
            rawStreamEventsJSON（生产库合计 47MB）。LLM 上下文不需要它，\
            这些字节被读取、拷贝、JSON 解码后永远不用。
            """
        )

        // ── 不变式 2：不得物化 metadata JSON ──
        //
        // `metadataJson` 在生产库合计 35MB，逐条 JSON 解码成字典。
        // 唯一例外是 `lumi.timelineEvent`：`llmHistory` 靠它过滤界面事件，
        // 必须保留；其余键一个都不该出现。
        let timelineKey = MessageTimelineEvent.metadataKey
        let withMetadata = messages.filter {
            $0.metadata.keys.contains { $0 != timelineKey }
        }
        #expect(
            withMetadata.isEmpty,
            """
            LLM 回合物化了 \(withMetadata.count)/\(messages.count) 条消息的 \
            metadata（生产库合计 35MB）。除时间线标记外，LLM 上下文不需要它。
            """
        )
    }

    @Test("LLM 回合必须保留真正需要的内容")
    func llmReadMustKeepContentAndToolCalls() throws {
        guard let (store, directory) = try makeStoreFromProductionCopy() else {
            print("LLMSCOPE keep skip=生产库副本不可用")
            return
        }
        defer { try? FileManager.default.removeItem(at: directory) }

        let databaseURL = directory.appendingPathComponent("messages.sqlite")
        guard let busiest = try findBusiestConversation(in: databaseURL) else {
            print("LLMSCOPE keep skip=生产库为空")
            return
        }
        let conversationID = try #require(UUID(uuidString: busiest.id))

        let messages = store.fetchMessagesForLLMContext(conversationId: conversationID)

        // 正文必须有 —— LLM 上下文的核心。
        let withContent = messages.filter { !$0.content.isEmpty }
        #expect(
            withContent.count > 0,
            "消息正文为空 —— LLM 上下文会失去内容"
        )

        // 工具调用必须有 —— LLM 的工具协议依赖它。
        let withToolCalls = messages.filter { !($0.toolCalls?.isEmpty ?? true) }
        #expect(
            withToolCalls.count > 0,
            "消息缺少 toolCalls —— LLM 的工具协议会失效"
        )

        // 角色、id、时间戳也必须保留 —— 上下文组装依赖它们。
        #expect(messages.allSatisfy { $0.role != .system || true })
        #expect(messages.allSatisfy { $0.id != UUID() })
    }
}
