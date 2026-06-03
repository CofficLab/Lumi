import Combine
import Foundation
import AgentToolKit

public enum ConversationListChangeType: String, Sendable {
    case created
    case updated
    case deleted
}

public struct ConversationListChange: Equatable, Sendable {
    public let type: ConversationListChangeType
    public let conversationId: UUID

    public init(type: ConversationListChangeType, conversationId: UUID) {
        self.type = type
        self.conversationId = conversationId
    }
}

public struct ConversationListItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let projectPath: String?
    public let title: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        projectPath: String? = nil,
        title: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectPath = projectPath
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return trimmed }

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return "对话-" + formatter.string(from: createdAt)
    }
}

@MainActor
public final class ConversationListContext: ObservableObject {
    @Published public var selectedConversationId: UUID?
    @Published public private(set) var lastChange: ConversationListChange?
    @Published public private(set) var statusVersion: Int = 0

    public var fetchAllConversationsProvider: () -> [ConversationListItem]
    public var fetchConversationsPageProvider: (_ limit: Int, _ offset: Int) -> [ConversationListItem]
    public var fetchConversationProvider: (_ id: UUID) -> ConversationListItem?
    public var selectConversationHandler: (_ id: UUID?, _ reason: String) -> Void
    public var deleteConversationHandler: (_ id: UUID) -> Bool
    public var updateConversationTitleHandler: (_ id: UUID, _ title: String) -> Bool
    public var updateProjectAssociationHandler: (_ id: UUID, _ projectPath: String?) -> Bool
    public var createConversationHandler: (_ projectName: String?, _ projectPath: String?, _ languagePreference: LanguagePreference) async -> UUID?
    public var switchProjectHandler: (_ projectPath: String, _ reason: String) -> Void
    public var isConversationProcessingProvider: (_ id: UUID) -> Bool
    public var databaseDirectoryProvider: () -> URL

    public init(
        selectedConversationId: UUID? = nil,
        fetchAllConversationsProvider: @escaping () -> [ConversationListItem] = { [] },
        fetchConversationsPageProvider: @escaping (_ limit: Int, _ offset: Int) -> [ConversationListItem] = { _, _ in [] },
        fetchConversationProvider: @escaping (_ id: UUID) -> ConversationListItem? = { _ in nil },
        selectConversationHandler: @escaping (_ id: UUID?, _ reason: String) -> Void = { _, _ in },
        deleteConversationHandler: @escaping (_ id: UUID) -> Bool = { _ in false },
        updateConversationTitleHandler: @escaping (_ id: UUID, _ title: String) -> Bool = { _, _ in false },
        updateProjectAssociationHandler: @escaping (_ id: UUID, _ projectPath: String?) -> Bool = { _, _ in false },
        createConversationHandler: @escaping (_ projectName: String?, _ projectPath: String?, _ languagePreference: LanguagePreference) async -> UUID? = { _, _, _ in nil },
        switchProjectHandler: @escaping (_ projectPath: String, _ reason: String) -> Void = { _, _ in },
        isConversationProcessingProvider: @escaping (_ id: UUID) -> Bool = { _ in false },
        databaseDirectoryProvider: @escaping () -> URL = {
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
        }
    ) {
        self.selectedConversationId = selectedConversationId
        self.fetchAllConversationsProvider = fetchAllConversationsProvider
        self.fetchConversationsPageProvider = fetchConversationsPageProvider
        self.fetchConversationProvider = fetchConversationProvider
        self.selectConversationHandler = selectConversationHandler
        self.deleteConversationHandler = deleteConversationHandler
        self.updateConversationTitleHandler = updateConversationTitleHandler
        self.updateProjectAssociationHandler = updateProjectAssociationHandler
        self.createConversationHandler = createConversationHandler
        self.switchProjectHandler = switchProjectHandler
        self.isConversationProcessingProvider = isConversationProcessingProvider
        self.databaseDirectoryProvider = databaseDirectoryProvider
    }

    public func fetchAllConversations() -> [ConversationListItem] {
        fetchAllConversationsProvider()
    }

    public func fetchConversationsPage(limit: Int, offset: Int) -> [ConversationListItem] {
        fetchConversationsPageProvider(limit, offset)
    }

    public func fetchConversation(id: UUID) -> ConversationListItem? {
        fetchConversationProvider(id)
    }

    public func selectConversation(_ id: UUID?, reason: String) {
        selectedConversationId = id
        selectConversationHandler(id, reason)
    }

    @discardableResult
    public func deleteConversation(id: UUID) -> Bool {
        deleteConversationHandler(id)
    }

    @discardableResult
    public func updateConversationTitle(id: UUID, title: String) -> Bool {
        updateConversationTitleHandler(id, title)
    }

    @discardableResult
    public func updateProjectAssociation(id: UUID, projectPath: String?) -> Bool {
        updateProjectAssociationHandler(id, projectPath)
    }

    public func createConversation(
        projectName: String?,
        projectPath: String?,
        languagePreference: LanguagePreference
    ) async -> UUID? {
        let id = await createConversationHandler(projectName, projectPath, languagePreference)
        selectedConversationId = id ?? selectedConversationId
        return id
    }

    public func switchProject(projectPath: String, reason: String) {
        switchProjectHandler(projectPath, reason)
    }

    public func isConversationProcessing(_ id: UUID) -> Bool {
        isConversationProcessingProvider(id)
    }

    public func databaseDirectory() -> URL {
        databaseDirectoryProvider()
    }

    public func notifyConversationChanged(_ change: ConversationListChange) {
        lastChange = change
    }

    public func notifyConversationStatusChanged() {
        statusVersion += 1
    }
}
