import Foundation
import SwiftData

struct ContextSummaryRecord: Sendable, Equatable {
    let conversationID: UUID
    let text: String
    let coveredThroughMessageID: UUID
    let sourceLastMessageID: UUID
    let providerID: String?
    let modelName: String?
    let sourceMessageCount: Int
    let updatedAt: Date
}

/// Serializes summary reads and writes on its own actor.
///
/// The directory is supplied by `StorageProviding` and must be the stable
/// plugin-ID directory, not a shared core directory.
actor ContextSummaryStore {
    static let databaseFileName = "context-summaries.sqlite"

    private let container: ModelContainer

    init(directory: URL) throws {
        self.container = try Self.makeContainer(directory: directory)
    }

    func load(conversationID: UUID) throws -> ContextSummaryRecord? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ContextSummaryModel>(
            predicate: #Predicate { $0.conversationID == conversationID }
        )
        descriptor.fetchLimit = 1
        guard let model = try context.fetch(descriptor).first else { return nil }
        return Self.record(from: model)
    }

    func save(_ record: ContextSummaryRecord) throws {
        let context = ModelContext(container)
        let conversationID = record.conversationID
        var descriptor = FetchDescriptor<ContextSummaryModel>(
            predicate: #Predicate { $0.conversationID == conversationID }
        )
        descriptor.fetchLimit = 1

        if let model = try context.fetch(descriptor).first {
            model.summary = record.text
            model.coveredThroughMessageID = record.coveredThroughMessageID
            model.sourceLastMessageID = record.sourceLastMessageID
            model.providerID = record.providerID
            model.modelName = record.modelName
            model.sourceMessageCount = record.sourceMessageCount
            model.updatedAt = record.updatedAt
            model.schemaVersion = 1
        } else {
            context.insert(
                ContextSummaryModel(
                    conversationID: record.conversationID,
                    summary: record.text,
                    coveredThroughMessageID: record.coveredThroughMessageID,
                    sourceLastMessageID: record.sourceLastMessageID,
                    providerID: record.providerID,
                    modelName: record.modelName,
                    sourceMessageCount: record.sourceMessageCount,
                    updatedAt: record.updatedAt
                )
            )
        }

        try context.save()
    }

    func remove(conversationID: UUID) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ContextSummaryModel>(
            predicate: #Predicate { $0.conversationID == conversationID }
        )
        for model in try context.fetch(descriptor) {
            context.delete(model)
        }
        try context.save()
    }

    private static func makeContainer(directory: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let schema = Schema([ContextSummaryModel.self])
        let databaseURL = directory.appendingPathComponent(databaseFileName)
        let configuration = ModelConfiguration(
            schema: schema,
            url: databaseURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func record(from model: ContextSummaryModel) -> ContextSummaryRecord {
        ContextSummaryRecord(
            conversationID: model.conversationID,
            text: model.summary,
            coveredThroughMessageID: model.coveredThroughMessageID,
            sourceLastMessageID: model.sourceLastMessageID,
            providerID: model.providerID,
            modelName: model.modelName,
            sourceMessageCount: model.sourceMessageCount,
            updatedAt: model.updatedAt
        )
    }
}
