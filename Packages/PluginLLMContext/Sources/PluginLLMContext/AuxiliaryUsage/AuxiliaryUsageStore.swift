import Foundation
import ProviderLLMContext
import SwiftData

/// 在自己的 actor 上串行化幕后用量读写的持久化存储。
///
/// 目录由 `StorageProviding` 提供，必须是稳定的插件 ID 目录。
actor AuxiliaryUsageStore {
    static let databaseFileName = "auxiliary-usage.sqlite"

    private let container: ModelContainer

    init(directory: URL) throws {
        self.container = try Self.makeContainer(directory: directory)
    }

    func save(_ entry: LLMAuxiliaryUsageEntry) throws {
        let context = ModelContext(container)
        context.insert(
            AuxiliaryUsageModel(
                id: entry.id,
                conversationID: entry.conversationID,
                purposeRaw: entry.purpose.rawValue,
                providerID: entry.providerID,
                modelName: entry.modelName,
                inputTokenCount: entry.inputTokenCount,
                outputTokenCount: entry.outputTokenCount,
                cachedInputTokenCount: entry.cachedInputTokenCount,
                cacheWriteInputTokenCount: entry.cacheWriteInputTokenCount,
                cacheTotalInputTokenCount: entry.cacheTotalInputTokenCount,
                isEstimated: entry.isEstimated,
                date: entry.date,
                sourceLastMessageID: entry.sourceLastMessageID
            )
        )
        try context.save()
    }

    func entries(for conversationID: UUID) throws -> [LLMAuxiliaryUsageEntry] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AuxiliaryUsageModel>(
            predicate: #Predicate { $0.conversationID == conversationID },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor).compactMap(Self.entry(from:))
    }

    func remove(conversationID: UUID) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AuxiliaryUsageModel>(
            predicate: #Predicate { $0.conversationID == conversationID }
        )
        for model in try context.fetch(descriptor) {
            context.delete(model)
        }
        try context.save()
    }

    private static func makeContainer(directory: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let schema = Schema([AuxiliaryUsageModel.self])
        let databaseURL = directory.appendingPathComponent(databaseFileName)
        let configuration = ModelConfiguration(
            schema: schema,
            url: databaseURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func entry(from model: AuxiliaryUsageModel) -> LLMAuxiliaryUsageEntry? {
        guard let purpose = LLMAuxiliaryPurpose(rawValue: model.purposeRaw) else { return nil }
        return LLMAuxiliaryUsageEntry(
            id: model.id,
            conversationID: model.conversationID,
            purpose: purpose,
            providerID: model.providerID,
            modelName: model.modelName,
            inputTokenCount: model.inputTokenCount,
            outputTokenCount: model.outputTokenCount,
            cachedInputTokenCount: model.cachedInputTokenCount,
            cacheWriteInputTokenCount: model.cacheWriteInputTokenCount,
            cacheTotalInputTokenCount: model.cacheTotalInputTokenCount,
            isEstimated: model.isEstimated,
            date: model.date,
            sourceLastMessageID: model.sourceLastMessageID
        )
    }
}