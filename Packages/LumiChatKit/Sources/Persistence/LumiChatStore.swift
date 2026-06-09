import Foundation
import LumiCoreKit
import SwiftData

@MainActor
struct LumiChatStore {
    struct Snapshot {
        var conversations: [LumiConversationSummary]
        var messagesByConversationID: [UUID: [LumiChatMessage]]
        var selectedConversationID: UUID?
        var selectedProviderID: String?
        var selectedModel: String?
        var routingMode: LumiModelRoutingMode

        static let empty = Snapshot(
            conversations: [],
            messagesByConversationID: [:],
            selectedConversationID: nil,
            selectedProviderID: nil,
            selectedModel: nil,
            routingMode: .manual
        )
    }

    private let container: ModelContainer
    private let context: ModelContext
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    init(configuration: LumiChatConfiguration, fileManager: FileManager = .default) {
        try? fileManager.createDirectory(
            at: configuration.databaseDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let schema = Schema([
            Conversation.self,
            ChatMessageEntity.self,
            ImageAttachmentEntity.self,
            ToolCallEntity.self,
            MessageMetricsEntity.self,
            LumiChatStateEntity.self,
        ])
        let storeURL = configuration.databaseDirectory
            .appendingPathComponent(configuration.databaseFileName, isDirectory: false)

        do {
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            Self.quarantineStoreFiles(baseURL: storeURL, fileManager: fileManager)
            do {
                let modelConfiguration = ModelConfiguration(
                    schema: schema,
                    url: storeURL,
                    allowsSave: true,
                    cloudKitDatabase: .none
                )
                self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                self.container = try! ModelContainer(for: schema, configurations: [fallbackConfiguration])
                assertionFailure("LumiChatKit failed to open SwiftData store and fell back to memory: \(error)")
            }
        }

        self.context = ModelContext(container)
    }

    func load() -> Snapshot {
        do {
            let conversationDescriptor = FetchDescriptor<Conversation>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            let conversationEntities = try context.fetch(conversationDescriptor)
            let conversations = conversationEntities.map(conversationSummary(from:))

            let messageDescriptor = FetchDescriptor<ChatMessageEntity>(
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            let messageEntities = try context.fetch(messageDescriptor)
            var messagesByConversationID: [UUID: [LumiChatMessage]] = [:]
            for entity in messageEntities {
                messagesByConversationID[entity.conversationId, default: []].append(message(from: entity))
            }

            let state = try currentState(createIfNeeded: false)
            let selectedID = state?.selectedConversationID.flatMap { id in
                conversations.contains(where: { $0.id == id }) ? id : conversations.first?.id
            } ?? conversations.first?.id

            return Snapshot(
                conversations: conversations,
                messagesByConversationID: messagesByConversationID,
                selectedConversationID: selectedID,
                selectedProviderID: state?.selectedProviderID,
                selectedModel: state?.selectedModel,
                routingMode: state?.routingMode.flatMap(LumiModelRoutingMode.init(rawValue:)) ?? .manual
            )
        } catch {
            assertionFailure("LumiChatKit failed to load SwiftData store: \(error)")
            return .empty
        }
    }

    func save(_ snapshot: Snapshot) {
        do {
            try upsertConversations(snapshot.conversations)
            try upsertMessages(snapshot.messagesByConversationID)
            let state = try currentState(createIfNeeded: true) ?? LumiChatStateEntity()
            state.selectedConversationID = snapshot.selectedConversationID
            state.selectedProviderID = snapshot.selectedProviderID
            state.selectedModel = snapshot.selectedModel
            state.routingMode = snapshot.routingMode.rawValue
            if state.modelContext == nil {
                context.insert(state)
            }
            try context.save()
        } catch {
            assertionFailure("LumiChatKit failed to save SwiftData store: \(error)")
        }
    }

    private func upsertConversations(_ conversations: [LumiConversationSummary]) throws {
        let existingEntities = try context.fetch(FetchDescriptor<Conversation>())
        let existingByID = Dictionary(uniqueKeysWithValues: existingEntities.map { ($0.id, $0) })
        let incomingIDs = Set(conversations.map(\.id))

        for entity in existingEntities where !incomingIDs.contains(entity.id) {
            context.delete(entity)
        }

        for conversation in conversations {
            let entity = existingByID[conversation.id] ?? Conversation(
                id: conversation.id,
                title: conversation.title
            )
            if entity.modelContext == nil {
                context.insert(entity)
            }
            entity.title = conversation.title
            entity.preview = conversation.preview
            entity.createdAt = conversation.createdAt
            entity.updatedAt = conversation.updatedAt
            entity.chatMode = conversation.automationLevel?.rawValue
            entity.verbosity = conversation.verbosity?.rawValue
            entity.languagePreference = conversation.language?.rawValue
            entity.providerId = conversation.providerID
            entity.model = conversation.modelName
        }
    }

    private func upsertMessages(_ messagesByConversationID: [UUID: [LumiChatMessage]]) throws {
        let existingEntities = try context.fetch(FetchDescriptor<ChatMessageEntity>())
        let existingByID = Dictionary(uniqueKeysWithValues: existingEntities.map { ($0.id, $0) })
        let incomingMessages = messagesByConversationID.values.flatMap { $0 }
        let incomingIDs = Set(incomingMessages.map(\.id))

        for entity in existingEntities where !incomingIDs.contains(entity.id) {
            context.delete(entity)
        }

        for message in incomingMessages {
            let entity = existingByID[message.id] ?? ChatMessageEntity(
                id: message.id,
                conversationId: message.conversationID,
                role: message.role.rawValue,
                content: message.content
            )
            if entity.modelContext == nil {
                context.insert(entity)
            }
            entity.conversationId = message.conversationID
            entity.role = message.role.rawValue
            entity.content = message.content
            entity.timestamp = message.createdAt
            entity.providerId = message.providerID
            entity.modelName = message.modelName
            entity.isError = message.isError
            entity.rawErrorDetail = message.rawErrorDetail
            entity.renderKind = message.renderKind
            entity.metadataJSON = encode(message.metadata)
            entity.toolCallsJSON = encode(message.toolCalls)
            entity.toolCallID = message.toolCallID
        }
    }

    private func currentState(createIfNeeded: Bool) throws -> LumiChatStateEntity? {
        var descriptor = FetchDescriptor<LumiChatStateEntity>(
            predicate: #Predicate { $0.id == "default" }
        )
        descriptor.fetchLimit = 1
        if let state = try context.fetch(descriptor).first {
            return state
        }
        guard createIfNeeded else {
            return nil
        }
        let state = LumiChatStateEntity()
        context.insert(state)
        return state
    }

    private func conversationSummary(from entity: Conversation) -> LumiConversationSummary {
        LumiConversationSummary(
            id: entity.id,
            title: entity.title,
            preview: entity.preview,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            verbosity: entity.verbosity.flatMap(LumiResponseVerbosity.init(rawValue:)),
            language: entity.languagePreference.flatMap(LumiConversationLanguage.init(rawValue:)),
            automationLevel: entity.chatMode.flatMap(LumiAutomationLevel.init(rawValue:)),
            providerID: entity.providerId,
            modelName: entity.model
        )
    }

    private func message(from entity: ChatMessageEntity) -> LumiChatMessage {
        LumiChatMessage(
            id: entity.id,
            conversationID: entity.conversationId,
            role: LumiChatMessageRole(rawValue: entity.role) ?? .assistant,
            content: entity.content,
            createdAt: entity.timestamp,
            providerID: entity.providerId,
            modelName: entity.modelName,
            isError: entity.isError,
            rawErrorDetail: entity.rawErrorDetail,
            renderKind: entity.renderKind,
            metadata: decode([String: String].self, from: entity.metadataJSON) ?? [:],
            toolCalls: decode([LumiToolCall].self, from: entity.toolCallsJSON),
            toolCallID: entity.toolCallID
        )
    }

    private func encode<T: Encodable>(_ value: T?) -> String? {
        guard let value,
              let data = try? jsonEncoder.encode(value)
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func decode<T: Decodable>(_ type: T.Type, from string: String?) -> T? {
        guard let string,
              let data = string.data(using: .utf8)
        else {
            return nil
        }
        return try? jsonDecoder.decode(type, from: data)
    }

    private static func quarantineStoreFiles(baseURL: URL, fileManager: FileManager) {
        let suffix = "corrupt-\(UUID().uuidString)"
        for url in [
            baseURL,
            URL(fileURLWithPath: baseURL.path + "-wal"),
            URL(fileURLWithPath: baseURL.path + "-shm"),
        ] where fileManager.fileExists(atPath: url.path) {
            let quarantinedURL = url.deletingLastPathComponent()
                .appendingPathComponent("\(url.lastPathComponent).\(suffix)")
            try? fileManager.moveItem(at: url, to: quarantinedURL)
        }
    }
}
