import Foundation
import SwiftData
import SuperLogKit
import LumiCoreMessage
import os

// MARK: - Error

public enum ConversationStoreError: Error, LocalizedError {
    case initializationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return message
        }
    }
}

/// Conversation storage service using SwiftData
///
/// Manages conversation persistence with SQLite database in plugin directory.
/// Thread-safe via Actor isolation, following `TaskStateManager` pattern.
public actor ConversationStore: SuperLog {
    nonisolated public static let emoji = "💬"
    nonisolated public static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "conversation.store")

    // MARK: - Properties

    private let container: ModelContainer

    // MARK: - Initialization

    public init(databaseRootURL: URL) throws {
        self.container = try Self.makeContainer(databaseRootURL: databaseRootURL)
    }

    static func makeContainer(databaseRootURL: URL) throws -> ModelContainer {
        let schema = Schema([ConversationModel.self])
        let dbDir = databaseRootURL.appendingPathComponent("ConversationManagerPlugin", isDirectory: true)
        let dbURL = dbDir.appendingPathComponent("conversations.sqlite")
        let fileManager = FileManager.default

        do {
            quarantineFileIfItBlocksDirectory(at: dbDir)
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
        } catch {
            throw ConversationStoreError.initializationFailed("ConversationManagerPlugin 数据库目录: \(error.localizedDescription)")
        }

        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)打开对话数据库失败，准备重建：\(error.localizedDescription)")
            }
            quarantinePersistentStore(at: dbURL)
        }

        // 重建尝试
        do {
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            throw ConversationStoreError.initializationFailed("ConversationManagerPlugin 数据库重建失败: \(error.localizedDescription)")
        }
    }

    private static func quarantinePersistentStore(at dbURL: URL) {
        let fileManager = FileManager.default
        let storeURLs = [
            dbURL,
            URL(fileURLWithPath: dbURL.path + "-shm"),
            URL(fileURLWithPath: dbURL.path + "-wal")
        ]

        for url in storeURLs where fileManager.fileExists(atPath: url.path) {
            quarantineFile(at: url)
        }
    }

    private static func quarantineFileIfItBlocksDirectory(at url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return
        }

        quarantineFile(at: url)
    }

    private static func quarantineFile(at url: URL) {
        let destination = url.deletingLastPathComponent()
            .appendingPathComponent(url.lastPathComponent + ".corrupt-\(Int(Date().timeIntervalSince1970))")
        do {
            try FileManager.default.moveItem(at: url, to: destination)
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)隔离对话数据库文件失败：\(error.localizedDescription)")
            }
        }
    }

    // MARK: - Create

    /// Create a new conversation with specific ID
    @discardableResult
    func createConversation(id: UUID, title: String, preview: String = "", createdAt: Date = Date()) throws -> ConversationModel {
        let context = ModelContext(container)
        let now = createdAt.timeIntervalSince1970
        let model = ConversationModel(
            id: id.uuidString,
            title: title,
            preview: preview,
            createdAt: now,
            updatedAt: now
        )
        context.insert(model)
        try context.save()

        if Self.verbose {
            Self.logger.info("\(Self.t)创建对话：\(title)")
        }

        return model
    }

    // MARK: - Read

    /// Fetch all conversations, sorted by updatedAt descending
    func fetchConversations() -> [LumiConversationSummary] {
        let context = ModelContext(container)

        var descriptor = FetchDescriptor<ConversationModel>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        do {
            let models = try context.fetch(descriptor)
            return models.compactMap { $0.toLumiConversationSummary() }
        } catch {
            Self.logger.error("\(Self.t)查询对话失败：\(error.localizedDescription)")
            return []
        }
    }

    /// Fetch a single conversation by ID
    func fetchConversation(id: UUID) -> LumiConversationSummary? {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        return try? context.fetch(descriptor).first?.toLumiConversationSummary()
    }

    // MARK: - Update

    /// Update conversation title
    func updateTitle(id: UUID, title: String) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        model.title = title
        model.updatedAt = Date().timeIntervalSince1970
        return save(context, operation: "更新标题")
    }

    /// Update conversation preview
    func updatePreview(id: UUID, preview: String) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        model.preview = preview
        model.updatedAt = Date().timeIntervalSince1970
        return save(context, operation: "更新预览")
    }

    /// Update conversation timestamp (mark as active)
    func touchConversation(id: UUID) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        model.updatedAt = Date().timeIntervalSince1970
        return save(context, operation: "更新活动时间")
    }

    /// Update conversation provider and model
    func updateConversationProvider(id: UUID, providerID: String, modelName: String?) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        model.providerId = providerID
        model.modelName = modelName
        model.updatedAt = Date().timeIntervalSince1970
        return save(context, operation: "更新供应商")
    }

    // MARK: - Delete

    /// Delete a conversation by ID
    func deleteConversation(id: UUID) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<ConversationModel>(
            predicate: #Predicate<ConversationModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        context.delete(model)
        return save(context, operation: "删除对话")
    }

    // MARK: - Private

    private func save(_ context: ModelContext, operation: StaticString) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            Self.logger.error("\(Self.t)\(operation)失败：\(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Database Root URL

public extension ConversationStore {
    /// Default database root URL (temporary directory)
    static var defaultDatabaseRootURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Lumi/ConversationManager")
    }
}
