import Foundation
import SwiftData

/// 在自己的 actor 上串行化压缩块读写的持久化存储（#1160）。
///
/// 目录由 `StorageProviding` 提供，必须是稳定的插件 ID 目录。读取返回某会话的
/// 全部块（含已停用块）：血缘回溯需要被折叠停用的低层块才能还原原始消息。
actor CompressionBlockStore {
    static let databaseFileName = "compression-blocks.sqlite"

    private let container: ModelContainer

    init(directory: URL) throws {
        self.container = try Self.makeContainer(directory: directory)
    }

    /// 读取某会话的全部块（含停用块），按 createdAt 升序。
    func load(conversationID: UUID) throws -> [CompressionBlock] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CompressionBlockModel>(
            predicate: #Predicate { $0.conversationID == conversationID },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor).map(Self.block(from:))
    }

    /// 批量 upsert：用于追加新块，或折叠时停用旧块 + 写入高层块（一次 save 原子提交）。
    func save(_ blocks: [CompressionBlock]) throws {
        guard !blocks.isEmpty else { return }
        let context = ModelContext(container)
        for block in blocks {
            let blockID = block.id
            var descriptor = FetchDescriptor<CompressionBlockModel>(
                predicate: #Predicate { $0.id == blockID }
            )
            descriptor.fetchLimit = 1
            if let model = try context.fetch(descriptor).first {
                model.tier = block.tier
                model.summary = block.summary
                model.sourceMessageIDsJSON = Self.encodeIDs(block.sourceMessageIDs)
                model.sourceBlockIDsJSON = Self.encodeIDs(block.sourceBlockIDs)
                model.coveredThroughMessageID = block.coveredThroughMessageID
                model.providerID = block.providerID
                model.modelName = block.modelName
                model.estimatedTokens = block.estimatedTokens
                model.createdAt = block.createdAt
                model.active = block.active
                model.schemaVersion = block.schemaVersion
            } else {
                context.insert(Self.model(from: block))
            }
        }
        try context.save()
    }

    /// 删除某会话的全部块（会话删除清理，#350）。
    func remove(conversationID: UUID) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CompressionBlockModel>(
            predicate: #Predicate { $0.conversationID == conversationID }
        )
        for model in try context.fetch(descriptor) {
            context.delete(model)
        }
        try context.save()
    }

    private static func makeContainer(directory: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let schema = Schema([CompressionBlockModel.self])
        let databaseURL = directory.appendingPathComponent(databaseFileName)
        let configuration = ModelConfiguration(
            schema: schema,
            url: databaseURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func model(from block: CompressionBlock) -> CompressionBlockModel {
        CompressionBlockModel(
            id: block.id,
            conversationID: block.conversationID,
            tier: block.tier,
            summary: block.summary,
            sourceMessageIDsJSON: encodeIDs(block.sourceMessageIDs),
            sourceBlockIDsJSON: encodeIDs(block.sourceBlockIDs),
            coveredThroughMessageID: block.coveredThroughMessageID,
            providerID: block.providerID,
            modelName: block.modelName,
            estimatedTokens: block.estimatedTokens,
            createdAt: block.createdAt,
            active: block.active,
            schemaVersion: block.schemaVersion
        )
    }

    private static func block(from model: CompressionBlockModel) -> CompressionBlock {
        CompressionBlock(
            id: model.id,
            conversationID: model.conversationID,
            tier: model.tier,
            summary: model.summary,
            sourceMessageIDs: decodeIDs(model.sourceMessageIDsJSON),
            sourceBlockIDs: decodeIDs(model.sourceBlockIDsJSON),
            coveredThroughMessageID: model.coveredThroughMessageID,
            providerID: model.providerID,
            modelName: model.modelName,
            estimatedTokens: model.estimatedTokens,
            createdAt: model.createdAt,
            active: model.active,
            schemaVersion: model.schemaVersion
        )
    }

    private static func encodeIDs(_ ids: [UUID]) -> String {
        guard let data = try? JSONEncoder().encode(ids),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private static func decodeIDs(_ json: String) -> [UUID] {
        guard let data = json.data(using: .utf8),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return ids
    }
}