import Foundation
import SwiftData
import LumiKernel

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
    }

    /// 消息条数(从 messagesJSON 解析,失败回退为 0)。
    var messagesCount: Int {
        guard let data = messagesJSON.data(using: .utf8),
              let messages = try? JSONDecoder().decode([LumiChatMessage].self, from: data) else {
            return 0
        }
        return messages.count
    }

    /// 工具个数(从 toolsJSON 解析,失败回退为 0)。
    var toolsCount: Int {
        guard let data = toolsJSON.data(using: .utf8),
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
actor AgentTurnRecordStore {
    static var defaultDatabaseRootURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.coffic.lumi/AgentTurnRunner", isDirectory: true)
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
    func record(request: LumiLLMRequest, conversationID: UUID, providerID: String?) {
        let model = AgentTurnRecordModel(
            id: UUID().uuidString,
            conversationID: conversationID.uuidString,
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

    /// 拉取全部记录(按时间倒序)。
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
