import Foundation
import SwiftData
import KernelLumi

/// 每次发出的 LLM 请求记录的纯数据副本,用于在 SwiftUI 视图中展示,
/// 与 SwiftData actor 隔离,避免跨 actor 传递 managed 对象。
struct AgentTurnRecordDTO: Identifiable, Sendable {
    let id: String
    let conversationID: String
    let createdAt: Date
    let model: String
    let providerID: String?
    let systemPrompt: String
    let messagesJSON: String
    let toolsJSON: String
    let imageAttachmentsCount: Int
    let fileAttachmentsCount: Int
    let messagesCount: Int
    let toolsCount: Int

    init(from model: AgentTurnRecordModel) {
        self.id = model.id
        self.conversationID = model.conversationID
        self.createdAt = model.createdAt
        self.model = model.model
        self.providerID = model.providerID
        self.systemPrompt = model.systemPrompt
        self.messagesJSON = model.messagesJSON
        self.toolsJSON = model.toolsJSON
        self.imageAttachmentsCount = model.imageAttachmentsCount
        self.fileAttachmentsCount = model.fileAttachmentsCount
        self.messagesCount = Self.decodeMessagesCount(model.messagesJSON)
        self.toolsCount = Self.decodeToolsCount(model.toolsJSON)
    }

    private static func decodeMessagesCount(_ json: String) -> Int {
        guard let data = json.data(using: .utf8),
              let messages = try? JSONDecoder().decode([LumiChatMessage].self, from: data) else {
            return 0
        }
        return messages.count
    }

    private static func decodeToolsCount(_ json: String) -> Int {
        guard let data = json.data(using: .utf8),
              let tools = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            return 0
        }
        return tools.count
    }
}

/// 使用 SwiftData 持久化「发出的请求」记录。
///
/// 存储目录规律与 ConversationStore 一致:数据库根目录取
/// `kernel.storage.pluginDataDirectory(for: "AgentTurnRunner")`,
/// SQLite 文件名沿用 `app.sqlite`。
///
/// Turn 级聚合:本 store 同时提供按 `turnID` 分组的查询能力,
/// 使 `AgentTurnRunner` 可以从 LLM 请求记录中聚合出 `AgentTurnRecord`。
actor AgentTurnRecordStore {
    static var defaultDatabaseRootURL: URL {
        let bundleIdentifier = Bundle.main.bundleIdentifier
            ?? LumiRuntimeEnvironment.productionBundleIdentifier
        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("AgentTurnRunner", isDirectory: true)
    }

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    /// - Parameter databaseRootURL: 数据库根目录(`pluginDataDirectory(for:)` 的返回值)。
    init(databaseRootURL: URL) {
        let schema = Schema([AgentTurnRecordModel.self])
        let storeURL = databaseRootURL.appendingPathComponent("app.sqlite", isDirectory: false)
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // 极少数情况下(如磁盘权限问题)回退到内存容器,保证不崩溃。
            container = (try? ModelContainer(for: AgentTurnRecordModel.self)) ?? (try! ModelContainer())
        }
        self.modelContainer = container
        self.modelContext = ModelContext(modelContainer)
        self.modelContext.autosaveEnabled = false
    }

    /// 记录一次发出的请求。
    ///
    /// - Parameters:
    ///   - request: LLM 请求快照
    ///   - conversationID: 所属对话
    ///   - turnID: 所属 AgentTurn (nil 表示 turn 跟踪之前的遗留请求)
    ///   - providerID: LLM 供应商标识
    func record(request: LumiLLMRequest, conversationID: UUID, turnID: UUID? = nil, providerID: String?) {
        let model = AgentTurnRecordModel(
            id: UUID().uuidString,
            conversationID: conversationID.uuidString,
            turnID: turnID?.uuidString,
            createdAt: Date(),
            model: request.model,
            providerID: providerID,
            systemPrompt: request.messages.first(where: { $0.role == .system })?.content ?? "",
            messagesJSON: Self.messagesJSON(from: request.messages),
            toolsJSON: Self.toolsJSON(from: request.tools),
            imageAttachmentsCount: request.imageAttachments.count,
            fileAttachmentsCount: request.fileAttachments.count
        )
        modelContext.insert(model)
        do {
            try modelContext.save()
        } catch {
            // SwiftData + NSFileCoordinator 有时会产生无害的 warning,忽略即可。
        }
    }

    // MARK: - Turn Aggregation Queries

    /// Returns all distinct turn IDs for a conversation, ordered by first-seen ascending.
    ///
    /// 用于 `AgentTurnRunner.turnRecords(for:)` 聚合:拿到所有 turnID 后,
    /// runner 可逐条从消息表和工具表中聚合统计,再叠加内存中的实时状态。
    func fetchTurnIDs(for conversationID: UUID) -> [UUID] {
        let conversationIDString = conversationID.uuidString
        let descriptor = FetchDescriptor<AgentTurnRecordModel>(
            predicate: #Predicate<AgentTurnRecordModel> {
                $0.conversationID == conversationIDString && $0.turnID != nil
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        guard let models = try? modelContext.fetch(descriptor) else { return [] }

        var seen: Set<UUID> = []
        var ordered: [UUID] = []
        for model in models {
            guard let idString = model.turnID, let id = UUID(uuidString: idString) else { continue }
            if seen.insert(id).inserted {
                ordered.append(id)
            }
        }
        return ordered
    }

    /// Returns the earliest request timestamp for a given turn ID.
    func fetchTurnStartedAt(turnID: UUID) -> Date? {
        let turnIDString = turnID.uuidString
        var descriptor = FetchDescriptor<AgentTurnRecordModel>(
            predicate: #Predicate<AgentTurnRecordModel> { $0.turnID == turnIDString },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        guard let first = try? modelContext.fetch(descriptor).first else { return nil }
        return first.createdAt
    }

    /// Returns the latest request timestamp for a given turn ID.
    func fetchTurnEndedAt(turnID: UUID) -> Date? {
        let turnIDString = turnID.uuidString
        var descriptor = FetchDescriptor<AgentTurnRecordModel>(
            predicate: #Predicate<AgentTurnRecordModel> { $0.turnID == turnIDString },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let last = try? modelContext.fetch(descriptor).first else { return nil }
        return last.createdAt
    }

    /// Returns the number of LLM requests made within a given turn.
    func fetchTurnRequestCount(turnID: UUID) -> Int {
        let turnIDString = turnID.uuidString
        let descriptor = FetchDescriptor<AgentTurnRecordModel>(
            predicate: #Predicate<AgentTurnRecordModel> { $0.turnID == turnIDString }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Legacy Queries

    /// Fetch one page of records using a keyset cursor.
    func fetchPage(limit: Int, beforeCreatedAt: Date? = nil, beforeID: String? = nil) -> [AgentTurnRecordDTO] {
        guard limit > 0 else { return [] }

        let cursorDate = beforeCreatedAt
        let cursorID = beforeID
        var descriptor: FetchDescriptor<AgentTurnRecordModel>
        if let cursorDate, let cursorID {
            descriptor = FetchDescriptor<AgentTurnRecordModel>(
                predicate: #Predicate<AgentTurnRecordModel> {
                    $0.createdAt < cursorDate ||
                    ($0.createdAt == cursorDate && $0.id < cursorID)
                },
                sortBy: [
                    SortDescriptor(\.createdAt, order: .reverse),
                    SortDescriptor(\.id, order: .reverse),
                ]
            )
        } else {
            descriptor = FetchDescriptor<AgentTurnRecordModel>(sortBy: [
                SortDescriptor(\.createdAt, order: .reverse),
                SortDescriptor(\.id, order: .reverse),
            ])
        }
        descriptor.fetchLimit = limit
        guard let models = try? modelContext.fetch(descriptor) else { return [] }
        return models.map { AgentTurnRecordDTO(from: $0) }
    }

    /// Count records without materializing request payloads.
    func count() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<AgentTurnRecordModel>())) ?? 0
    }

    func fetchDailyCountSeries(days: Int = 14, endingAt date: Date = Date()) -> AgentTurnDailyCountSeries {
        guard days > 0 else { return AgentTurnDailyCountSeries(points: []) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let firstDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        let points = (0..<days).compactMap { offset -> AgentTurnDailyCountPoint? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                return nil
            }

            let descriptor = FetchDescriptor<AgentTurnRecordModel>(
                predicate: #Predicate<AgentTurnRecordModel> {
                    $0.createdAt >= day && $0.createdAt < nextDay
                }
            )
            let count = (try? modelContext.fetchCount(descriptor)) ?? 0
            return AgentTurnDailyCountPoint(day: day, count: count)
        }
        return AgentTurnDailyCountSeries(points: points)
    }

    /// Legacy full fetch retained for non-settings callers.
    func fetchAll() -> [AgentTurnRecordDTO] {
        let descriptor = FetchDescriptor<AgentTurnRecordModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let models = try? modelContext.fetch(descriptor) else { return [] }
        return models.map { AgentTurnRecordDTO(from: $0) }
    }

    func delete(id: String) {
        let descriptor = FetchDescriptor<AgentTurnRecordModel>(
            predicate: #Predicate { $0.id == id }
        )
        guard let models = try? modelContext.fetch(descriptor) else { return }
        for m in models { modelContext.delete(m) }
        try? modelContext.save()
    }

    func deleteAll() {
        let descriptor = FetchDescriptor<AgentTurnRecordModel>()
        guard let models = try? modelContext.fetch(descriptor) else { return }
        for m in models { modelContext.delete(m) }
        try? modelContext.save()
    }

    // MARK: - 序列化辅助

    private static func messagesJSON(from messages: [LumiChatMessage]) -> String {
        guard let data = try? JSONEncoder().encode(messages),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    private static func toolsJSON(from tools: [any LumiAgentTool]) -> String {
        let items: [[String: String]] = tools.map { tool in
            let schemaString: String
            if let data = try? JSONEncoder().encode(tool.inputSchema),
               let string = String(data: data, encoding: .utf8) {
                schemaString = string
            } else {
                schemaString = ""
            }
            return [
                "name": tool.name,
                "description": tool.toolDescription,
                "inputSchema": schemaString,
            ]
        }
        guard let data = try? JSONEncoder().encode(items),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}

enum AgentTurnRecordPayloadDecoder {
    nonisolated static func messages(from json: String) -> [LumiChatMessage] {
        guard let data = json.data(using: .utf8),
              let messages = try? JSONDecoder().decode([LumiChatMessage].self, from: data) else {
            return []
        }
        return messages
    }

    nonisolated static func tools(from json: String) -> [[String: String]] {
        guard let data = json.data(using: .utf8),
              let tools = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            return []
        }
        return tools
    }
}
