import Foundation
import LumiCoreMessage
import os
import SuperLogKit
import SwiftData

/// Message storage service using SwiftData
///
/// Manages message persistence with SQLite database in plugin directory.
/// Thread-safe via Actor isolation, following `TaskStateManager` pattern.
public actor MessageStore: SuperLog {
    public nonisolated static let emoji = "💬"
    public nonisolated static let verbose = true
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "message.store")

    // MARK: - Properties

    private let container: ModelContainer

    // MARK: - Initialization

    public init(databaseRootURL: URL) throws {
        self.container = try Self.makeContainer(databaseRootURL: databaseRootURL)
    }

    static func makeContainer(databaseRootURL: URL) throws -> ModelContainer {
        let schema = Schema([MessageModel.self])
        let dbDir = databaseRootURL.appendingPathComponent("MessageManagerPlugin", isDirectory: true)
        let dbURL = dbDir.appendingPathComponent("messages.sqlite")
        let fileManager = FileManager.default

        do {
            quarantineFileIfItBlocksDirectory(at: dbDir)
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
        } catch {
            throw MessageStoreError.initializationFailed("MessageManagerPlugin 数据库目录: \(error.localizedDescription)")
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
                Self.logger.error("\(Self.t)打开消息数据库失败，准备重建：\(error.localizedDescription)")
            }
            quarantinePersistentStore(at: dbURL)
        }

        // 重建尝试
        do {
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            throw MessageStoreError.initializationFailed("MessageManagerPlugin 数据库重建失败: \(error.localizedDescription)")
        }
    }

    private static func quarantinePersistentStore(at dbURL: URL) {
        let fileManager = FileManager.default
        let storeURLs = [
            dbURL,
            URL(fileURLWithPath: dbURL.path + "-shm"),
            URL(fileURLWithPath: dbURL.path + "-wal"),
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
                Self.logger.error("\(Self.t)隔离消息数据库文件失败：\(error.localizedDescription)")
            }
        }
    }

    // MARK: - Create / Insert

    /// Insert a new message
    @discardableResult
    func insertMessage(_ message: LumiChatMessage) throws -> MessageModel {
        let context = ModelContext(container)
        let model = MessageModel.from(message: message)
        context.insert(model)
        try context.save()

        if Self.verbose {
            Self.logger.info("\(Self.t)插入消息：\(message.id) to conversation \(message.conversationID)")
        }

        return model
    }

    // MARK: - Read

    /// Fetch all messages for a conversation, sorted by createdAt
    func fetchMessages(conversationId: UUID) -> [LumiChatMessage] {
        let context = ModelContext(container)
        let conversationIdString = conversationId.uuidString

        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.conversationId == conversationIdString },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        do {
            let models = try context.fetch(descriptor)
            return models.compactMap { $0.toLumiChatMessage() }
        } catch {
            Self.logger.error("\(Self.t)查询消息失败：\(error.localizedDescription)")
            return []
        }
    }

    /// Fetch a single message by ID
    func fetchMessage(id: UUID) -> LumiChatMessage? {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.id == idString }
        )

        return try? context.fetch(descriptor).first?.toLumiChatMessage()
    }

    // MARK: - Update

    /// Update message content
    func updateMessage(id: UUID, content: String) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        model.content = content
        return save(context, operation: "更新消息")
    }

    // MARK: - Delete

    /// Delete a message by ID
    func deleteMessage(id: UUID) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        context.delete(model)
        return save(context, operation: "删除消息")
    }

    /// Delete all messages for a conversation
    func deleteAllMessages(conversationId: UUID) -> Bool {
        let context = ModelContext(container)
        let conversationIdString = conversationId.uuidString

        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.conversationId == conversationIdString }
        )

        do {
            let models = try context.fetch(descriptor)
            for model in models {
                context.delete(model)
            }
            try context.save()
            return true
        } catch {
            Self.logger.error("\(Self.t)删除会话消息失败：\(error.localizedDescription)")
            return false
        }
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

public extension MessageStore {
    /// Default database root URL (temporary directory)
    static var defaultDatabaseRootURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Lumi/MessageManager")
    }
}
