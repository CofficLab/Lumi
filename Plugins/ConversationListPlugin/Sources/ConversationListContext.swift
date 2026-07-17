import Combine
import Foundation
import LumiChatKit
import LumiCoreKit

@MainActor
public final class ConversationListContext: ObservableObject {
    @Published public private(set) var lastChange: ConversationListChange?
    @Published public private(set) var statusVersion: Int = 0
    @Published public private(set) var unreadCount: Int = 0

    private let chatService: ChatService
    private let projectPathStore: ProjectComponent?
    private let projectStore: ProjectComponent?
    private weak var lumiCore: LumiCore?
    private var conversationSnapshots: [UUID: Date] = [:]
    private var cancellables = Set<AnyCancellable>()

    public init(
        chatService: ChatService,
        projectPathStore: ProjectComponent? = nil,
        projectStore: ProjectComponent? = nil,
        lumiCore: LumiCore? = nil
    ) {
        self.chatService = chatService
        self.projectPathStore = projectPathStore
        self.projectStore = projectStore
        self.lumiCore = lumiCore

        conversationSnapshots = Dictionary(
            uniqueKeysWithValues: chatService.conversations.map { ($0.id, $0.updatedAt) }
        )
        bindChatService()
    }

    public var selectedConversationId: UUID? {
        chatService.selectedConversationID
    }

    private var selectedConversationUpdatedAt: Date? {
        guard let selectedConversationId else { return nil }
        return chatService.conversations.first(where: { $0.id == selectedConversationId })?.updatedAt
    }

    private func recalculateUnreadCount() {
        let selectedUpdatedAt = selectedConversationUpdatedAt
        guard let selectedUpdatedAt else {
            unreadCount = 0
            return
        }

        unreadCount = chatService.conversations.filter { $0.updatedAt > selectedUpdatedAt }.count
    }

    public func databaseDirectory() -> URL {
        lumiCore?.storage.coreDataDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    public func fetchConversationsPage(limit: Int, offset: Int) -> [ConversationListItem] {
        let sorted = chatService.conversations.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.updatedAt > rhs.updatedAt
        }
        return sorted
            .dropFirst(offset)
            .prefix(limit)
            .map { ConversationListItem.from($0) }
    }

    public func fetchConversation(id: UUID) -> ConversationListItem? {
        chatService.conversations.first(where: { $0.id == id }).map(ConversationListItem.from)
    }

    public func isConversationProcessing(_ conversationID: UUID) -> Bool {
        chatService.isSending(for: conversationID)
    }

    @discardableResult
    public func deleteConversation(id: UUID) -> Bool {
        guard chatService.conversations.contains(where: { $0.id == id }) else {
            return false
        }
        chatService.deleteConversation(id: id)
        return true
    }

    public func selectConversation(_ id: UUID?, reason: String) {
        guard let id else { return }
        chatService.selectConversation(id: id)
    }

    @discardableResult
    public func createConversation() -> UUID {
        chatService.createConversation(title: nil)
    }

    public func switchProject(projectPath: String, reason: String) {
        // 优先走 LumiProjectState（Layer B）：它会让 ProjectsStore.currentProject、
        // 持久化 current-project.json、以及内核 Layer A 三者一致，
        // 这样标题栏 ProjectControlView 才会同步刷新，且重启后状态保留。
        if let projectStore {
            projectStore.setCurrentProjectPath(projectPath)
            return
        }

        // 降级：没有 projectStore 时只更新内核路径（与旧行为一致）。
        projectPathStore?.setCurrentProjectPath(projectPath)
    }

    private func bindChatService() {
        chatService.$conversations
            .receive(on: RunLoop.main)
            .sink { [weak self] conversations in
                self?.publishConversationChanges(conversations)
            }
            .store(in: &cancellables)

        chatService.$revision
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.statusVersion += 1
            }
            .store(in: &cancellables)

        chatService.$selectedConversationID
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.recalculateUnreadCount()
            }
            .store(in: &cancellables)
    }

    private func publishConversationChanges(_ conversations: [LumiConversationSummary]) {
        let nextSnapshots = Dictionary(uniqueKeysWithValues: conversations.map { ($0.id, $0.updatedAt) })
        let previousIDs = Set(conversationSnapshots.keys)
        let nextIDs = Set(nextSnapshots.keys)

        if let createdID = nextIDs.subtracting(previousIDs).first {
            lastChange = ConversationListChange(type: .created, conversationId: createdID)
        } else if let deletedID = previousIDs.subtracting(nextIDs).first {
            lastChange = ConversationListChange(type: .deleted, conversationId: deletedID)
        } else if let updatedID = nextIDs.intersection(previousIDs).first(where: { id in
            conversationSnapshots[id] != nextSnapshots[id]
        }) {
            lastChange = ConversationListChange(type: .updated, conversationId: updatedID)
        }

        conversationSnapshots = nextSnapshots
        statusVersion += 1
        recalculateUnreadCount()
    }
}
