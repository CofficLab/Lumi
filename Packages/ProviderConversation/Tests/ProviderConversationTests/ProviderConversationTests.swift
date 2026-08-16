import Combine
import Foundation
import XCTest
@testable import ProviderConversation

/// `DefaultConversationManaging` 内存实现的单元测试。
@MainActor
final class ProviderConversationTests: XCTestCase {

    func testCreateConversationSelectsAndUpdatesTitle() throws {
        let manager = DefaultConversationManaging()

        let id = try manager.createConversation(
            title: "  你好 Lumi  ",
            projectPath: "/tmp/proj",
            providerID: "openai",
            modelName: "gpt-4o"
        )

        XCTAssertEqual(manager.conversations.count, 1)
        XCTAssertEqual(manager.selectedConversationID, id)
        XCTAssertEqual(manager.currentTitle, "你好 Lumi")
        XCTAssertEqual(manager.providerID(for: id), "openai")
        XCTAssertEqual(manager.modelName(for: id), "gpt-4o")
        XCTAssertEqual(manager.conversations.first?.projectPath, "/tmp/proj")
    }

    func testEmptyTitleFallsBackToUntitled() throws {
        let manager = DefaultConversationManaging()
        let id = try manager.createConversation(title: "   ", projectPath: nil, providerID: nil, modelName: nil)

        XCTAssertNil(manager.conversations.first?.title)
        XCTAssertEqual(manager.currentTitle, "Untitled")
        XCTAssertEqual(manager.conversations.first?.displayTitle, "Untitled")
        XCTAssertFalse(manager.conversations.first?.hasCustomTitle ?? true)
    }

    func testSelectDeselectDelete() throws {
        let manager = DefaultConversationManaging()
        let first = try manager.createConversation(title: "A", projectPath: nil, providerID: nil, modelName: nil)
        let second = try manager.createConversation(title: "B", projectPath: nil, providerID: nil, modelName: nil)

        XCTAssertEqual(manager.selectedConversationID, second)

        manager.selectConversation(id: first)
        XCTAssertEqual(manager.selectedConversationID, first)
        XCTAssertEqual(manager.currentTitle, "A")

        manager.deselectConversation()
        XCTAssertNil(manager.selectedConversationID)
        XCTAssertEqual(manager.currentTitle, "No conversation")

        manager.deleteConversation(id: second)
        XCTAssertEqual(manager.conversations.count, 1)
        XCTAssertEqual(manager.conversations.first?.id, first)
    }

    func testSortedConversationsByLastMessage() throws {
        let manager = DefaultConversationManaging()
        let older = try manager.createConversation(title: "older", projectPath: nil, providerID: nil, modelName: nil)
        let newer = try manager.createConversation(title: "newer", projectPath: nil, providerID: nil, modelName: nil)

        // 让 older 收到新消息，应置顶。
        let messageDate = Date().addingTimeInterval(60)
        manager.markConversationActive(id: older, messageDate: messageDate)

        XCTAssertEqual(manager.sortedConversations.map(\.id), [older, newer])
        XCTAssertEqual(manager.conversations.first { $0.id == older }?.lastMessageAt, messageDate)
    }

    func testUpdateTitle() throws {
        let manager = DefaultConversationManaging()
        let id = try manager.createConversation(title: "Old", projectPath: nil, providerID: nil, modelName: nil)

        XCTAssertTrue(manager.updateConversationTitle("New Title", for: id))
        XCTAssertEqual(manager.currentTitle, "New Title")

        XCTAssertFalse(manager.updateConversationTitle("x", for: UUID()))
    }

    func testPerConversationPreferences() throws {
        let manager = DefaultConversationManaging()
        let id = try manager.createConversation(title: nil, projectPath: nil, providerID: nil, modelName: nil)

        // 默认继承全局设置
        XCTAssertEqual(manager.verbosity(for: id), .defaultVerbosity)
        XCTAssertEqual(manager.reasoningEffort(for: id), .defaultEffort)
        XCTAssertEqual(manager.automationLevel(for: id), .build)
        XCTAssertEqual(manager.language(for: id), .chinese)

        // 按对话覆盖
        manager.setVerbosity(.detailed, for: id)
        manager.setReasoningEffort(.max, for: id)
        manager.setAutomationLevel(.autonomous, for: id)
        manager.setLanguage(.english, for: id)

        XCTAssertEqual(manager.verbosity(for: id), .detailed)
        XCTAssertEqual(manager.reasoningEffortOptional(for: id), .max)
        XCTAssertEqual(manager.automationLevel(for: id), .autonomous)
        XCTAssertEqual(manager.language(for: id), .english)

        // 清除推理强度 → nil
        manager.clearReasoningEffort(for: id)
        XCTAssertNil(manager.reasoningEffortOptional(for: id))
        XCTAssertEqual(manager.reasoningEffort(for: id), .defaultEffort)
    }

    func testGlobalPreferencesApplyToNewConversations() throws {
        let manager = DefaultConversationManaging()
        manager.setGlobalVerbosity(.brief)
        manager.setGlobalReasoningEffort(.low)
        manager.setGlobalAutomationLevel(.chat)
        manager.setGlobalLanguage(.english)

        let id = try manager.createConversation(title: nil, projectPath: nil, providerID: nil, modelName: nil)

        XCTAssertEqual(manager.verbosity(for: id), .brief)
        XCTAssertEqual(manager.reasoningEffort(for: id), .low)
        XCTAssertEqual(manager.automationLevel(for: id), .chat)
        XCTAssertEqual(manager.language(for: id), .english)
    }

    func testConversationCountAndProjectCount() async throws {
        let manager = DefaultConversationManaging()
        _ = try manager.createConversation(title: "A", projectPath: "/p1", providerID: nil, modelName: nil)
        _ = try manager.createConversation(title: "B", projectPath: "/p1", providerID: nil, modelName: nil)
        _ = try manager.createConversation(title: "C", projectPath: "/p2", providerID: nil, modelName: nil)

        let all = await manager.conversationCount(projectPath: nil)
        let p1 = await manager.conversationCount(projectPath: "/p1")
        let projects = await manager.conversationProjectCount()

        XCTAssertEqual(all, 3)
        XCTAssertEqual(p1, 2)
        XCTAssertEqual(projects, 2)
    }

    func testFetchConversationPageFiltersByProject() async throws {
        let manager = DefaultConversationManaging()
        _ = try manager.createConversation(title: "A", projectPath: "/p1", providerID: nil, modelName: nil)
        _ = try manager.createConversation(title: "B", projectPath: "/p2", providerID: nil, modelName: nil)

        let p1 = await manager.fetchConversationPage(limit: 10, beforeUpdatedAt: nil, beforeID: nil, includingChildConversations: true, projectPath: "/p1")
        XCTAssertEqual(p1.map(\.title), ["A"])
    }
}
