import Foundation
@testable import PluginConversationNew

/// 测试用会话能力替身。
///
/// 记录调用序列，用于断言「创建对话后立刻恢复选中态」这一关键不变量。
@MainActor
final class MockNewChatCapability: NewChatCapability {
    private(set) var selectedID: UUID?
    private(set) var createdConversations: [(title: String?, projectPath: String?, modelID: String?)] = []
    private(set) var restoredSelections: [UUID?] = []
    private(set) var selections: [UUID] = []
    var modelID: String?
    var projectPath: String?
    /// 下一次创建时抛出的错误；nil 表示成功。
    var createError: Error?

    var selectedConversationID: UUID? { selectedID }
    var currentModelID: String? { modelID }
    var currentProjectPath: String? { projectPath }

    func createTopLevelConversation(
        title: String?,
        projectPath: String?,
        modelID: String?
    ) throws -> UUID {
        createdConversations.append((title, projectPath, modelID))
        if let createError { throw createError }
        let id = UUID()
        // 复刻内核行为：顶层对话创建后自动成为选中态。
        selectedID = id
        return id
    }

    func selectConversation(id: UUID) {
        selections.append(id)
        selectedID = id
    }

    func restoreSelection(to conversationID: UUID?) {
        restoredSelections.append(conversationID)
        selectedID = conversationID
    }

    func deselectConversation() {
        selectedID = nil
    }
}
