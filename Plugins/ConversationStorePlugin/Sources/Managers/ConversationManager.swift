import Foundation
import LumiKernel
import SuperLogKit
import os

/// Conversation Manager - real implementation using SwiftData persistence
///
/// Uses in-memory array for sync access, persists to SQLite async via ConversationStore.
@MainActor
public final class ConversationManager: ObservableObject, ConversationManaging, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-manager")
    nonisolated public static let emoji = "💬"
    public static let verbose = false

    @Published public private(set) var conversations: [LumiConversationSummary] = []
    @Published public private(set) var selectedConversationID: UUID?
    @Published public private(set) var currentTitle: String = "No conversation"

    /// Notification posted when conversations list changes
    static let conversationsDidChangeNotification = Notification.Name.lumiConversationsDidChange

    private weak var kernel: LumiKernel?

    public var dataDirectory: URL {
        ConversationManagerRuntimeBridge.shared.dataDirectory ?? ConversationStore.defaultDatabaseRootURL
    }

    // MARK: - Initialization

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        if Self.verbose {
            Self.logger.info("\(Self.t)ConversationManager initialized")
        }
    }

    // MARK: - Store Access

    private var store: ConversationStore? {
        ConversationManagerRuntimeBridge.shared.store
    }

    // MARK: - Load

    /// Load conversations from store (called during boot)
    public func loadConversations() {
        guard let store else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)Store not available, using empty list")
            }
            conversations = []
            return
        }

        // Synchronous load on MainActor - the store.fetchConversations is async but we await it
        Task {
            let loaded = await store.fetchConversations()
            await MainActor.run {
                self.conversations = loaded
                if self.selectedConversationID == nil {
                    self.selectedConversationID = self.loadPersistedSelectedConversationID()
                }

                // Restore selected conversation if it still exists
                if let selectedID = self.selectedConversationID,
                   !loaded.contains(where: { $0.id == selectedID }) {
                    self.selectedConversationID = loaded.first?.id
                }
                self.updateCurrentTitle()
                self.persistSelectedConversationID()
                self.notifyConversationsChanged()

                if Self.verbose {
                    Self.logger.info("\(Self.t)Loaded \(loaded.count) conversations")
                }
            }
        }
    }

    /// Notify observers that conversations changed
    private func notifyConversationsChanged() {
        kernel?.eventManager.postConversationsDidChange(object: self)
    }

    // MARK: - ConversationManaging

    public func createConversation(title: String?, projectPath: String?) throws -> UUID {
        let now = Date()
        let id = UUID()
        let conversationTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = conversationTitle?.isEmpty == true ? nil : conversationTitle

        // 如果未指定 projectPath，则自动使用当前项目
        let effectiveProjectPath = projectPath ?? kernel?.project?.currentProject?.path

        if Self.verbose {
            Self.logger.info("\(Self.t)创建对话：\(normalizedTitle ?? "nil"), 项目：\(effectiveProjectPath ?? "nil")")
        }

        let conversation = LumiConversationSummary(
            id: id,
            title: normalizedTitle,
            preview: "",
            createdAt: now,
            updatedAt: now,
            projectPath: effectiveProjectPath
        )

        // Add to in-memory list immediately
        conversations.insert(conversation, at: 0)
        selectedConversationID = id
        updateCurrentTitle()
        notifyConversationsChanged()
        persistSelectedConversationID()

        // Persist to database async
        Task {
            do {
                try await store?.createConversation(id: id, title: normalizedTitle, preview: "", createdAt: now, projectPath: effectiveProjectPath)
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)Failed to persist conversation: \(error)")
                }
            }
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)Created conversation \(id.uuidString.prefix(8))...")
        }

        return id
    }

    public func selectConversation(id: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)Selecting conversation \(id.uuidString.prefix(8))...")
        }
        selectedConversationID = id
        updateCurrentTitle()
        persistSelectedConversationID()

        // Touch the conversation to update its timestamp (async)
        Task {
            await store?.touchConversation(id: id)
        }
    }

    public func deleteConversation(id: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)Deleting conversation \(id.uuidString.prefix(8))...")
        }

        conversations.removeAll { $0.id == id }

        if selectedConversationID == id {
            selectedConversationID = conversations.first?.id
            updateCurrentTitle()
            persistSelectedConversationID()
        }

        notifyConversationsChanged()

        // Delete from database async
        Task {
            await store?.deleteConversation(id: id)
        }
    }

    public func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return false
        }
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedTitle = normalized.isEmpty ? nil : normalized
        conversations[index].title = storedTitle

        if conversationID == selectedConversationID {
            updateCurrentTitle()
        }
        notifyConversationsChanged()

        // 持久化到数据库（异步）
        Task {
            await store?.updateTitle(id: conversationID, title: normalized)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)updateConversationTitle: conversation=\(conversationID.uuidString.prefix(8)), title=\(storedTitle ?? "nil")")
        }
        return true
    }

    public func isSending(for conversationID: UUID?) -> Bool {
        // TODO: Implement based on actual sending state
        return false
    }

    public func mockConversationIDs() -> [UUID] {
        // Return actual conversation IDs for message data association
        conversations.map(\.id)
    }

    // MARK: - Provider/Model Selection

    public func providerID(for conversationID: UUID?) -> String? {
        guard let conversationID else {
            return nil
        }
        return conversations.first { $0.id == conversationID }?.providerID
    }

    public func modelName(for conversationID: UUID?) -> String? {
        guard let conversationID else {
            return nil
        }
        return conversations.first { $0.id == conversationID }?.modelName
    }

    public func selectProvider(id: String, model: String?, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].providerID = id
        conversations[index].modelName = model

        // Persist to database async
        Task {
            await store?.updateConversationProvider(id: conversationID, providerID: id, modelName: model)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)selectProvider: conversation=\(conversationID.uuidString.prefix(8)), provider=\(id), model=\(model ?? "nil")")
        }
    }

    // MARK: - Verbosity

    public func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity {
        guard let conversationID else {
            return .defaultVerbosity
        }
        return conversations.first { $0.id == conversationID }?.verbosity ?? .defaultVerbosity
    }

    public func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].verbosity = verbosity
        // 重新赋值触发 @Published，并广播变更通知，使依赖该会话 verbosity 的视图
        // （消息列表、工具栏等）即时刷新：消息列表会据此重新加载（工具消息的显隐）
        // 并注入新的 verbosity 环境值。
        conversations = conversations
        notifyConversationsChanged()

        if Self.verbose {
            Self.logger.info("\(Self.t)setVerbosity: conversation=\(conversationID.uuidString.prefix(8)), verbosity=\(verbosity.rawValue)")
        }
    }

    // MARK: - Automation Level

    public func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel {
        guard let conversationID else {
            return .build
        }
        return conversations.first { $0.id == conversationID }?.automationLevel ?? .build
    }

    public func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].automationLevel = automationLevel

        if Self.verbose {
            Self.logger.info("\(Self.t)setAutomationLevel: conversation=\(conversationID.uuidString.prefix(8)), level=\(automationLevel.rawValue)")
        }
    }

    // MARK: - Language

    public func language(for conversationID: UUID?) -> LumiConversationLanguage {
        guard let conversationID else {
            return .chinese
        }
        return conversations.first { $0.id == conversationID }?.language ?? .chinese
    }

    public func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].language = language

        if Self.verbose {
            Self.logger.info("\(Self.t)setLanguage: conversation=\(conversationID.uuidString.prefix(8)), language=\(language.rawValue)")
        }
    }

    // MARK: - Private

    private func updateCurrentTitle() {
        guard let selectedID = selectedConversationID,
              let conversation = conversations.first(where: { $0.id == selectedID })
        else {
            currentTitle = "No conversation"
            return
        }
        let newTitle = conversation.displayTitle
        currentTitle = newTitle
    }

    private func loadPersistedSelectedConversationID() -> UUID? {
        guard let data = try? Data(contentsOf: stateFileURL),
              let state = try? JSONDecoder().decode(ConversationState.self, from: data) else {
            return nil
        }
        return state.selectedConversationID
    }

    private func persistSelectedConversationID() {
        let state = ConversationState(selectedConversationID: selectedConversationID)
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }

        let directory = stateFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: stateFileURL, options: .atomic)
    }

    private var stateFileURL: URL {
        dataDirectory
            .appendingPathComponent("state.json", isDirectory: false)
    }
}

// MARK: - Runtime Bridge

private struct ConversationState: Codable {
    let selectedConversationID: UUID?
}

@MainActor
final class ConversationManagerRuntimeBridge: @unchecked Sendable {
    static let shared = ConversationManagerRuntimeBridge()

    var store: ConversationStore?
    var dataDirectory: URL?

    private init() {}
}
