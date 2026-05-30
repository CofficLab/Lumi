import Testing
import Foundation
@testable import PluginHistoryDBStatusBar
@testable import LumiCoreKit

// MARK: - Mock HistoryQueryService

/// 用于测试的 Mock 实现
@MainActor
final class MockHistoryQueryService: HistoryQueryService {
    var messageCount: Int = 0
    var conversationCount: Int = 0
    var messagePages: [Int: [HistoryMessageRow]] = [:]   // offset → rows
    var conversationPages: [Int: [HistoryConversationRow]] = [:]

    func fetchMessageCount() async -> Int {
        messageCount
    }

    func fetchMessagePage(limit: Int, offset: Int) async -> [HistoryMessageRow] {
        messagePages[offset] ?? []
    }

    func fetchConversationCount() async -> Int {
        conversationCount
    }

    func fetchConversationPage(limit: Int, offset: Int) async -> [HistoryConversationRow] {
        conversationPages[offset] ?? []
    }
}

// MARK: - Test Helpers

private extension HistoryMessageRow {
    static func fixture(
        id: UUID = UUID(),
        conversationId: UUID = UUID(),
        conversationTitle: String = "Test Conversation",
        role: String = "user",
        model: String = "gpt-4o",
        tokens: Int = 100,
        timestamp: Date = Date(),
        contentPreview: String = "Hello world"
    ) -> HistoryMessageRow {
        HistoryMessageRow(
            id: id,
            conversationId: conversationId,
            conversationTitle: conversationTitle,
            role: role,
            model: model,
            tokens: tokens,
            timestamp: timestamp,
            contentPreview: contentPreview
        )
    }
}

private extension HistoryConversationRow {
    static func fixture(
        id: UUID = UUID(),
        title: String = "Test Conversation",
        projectId: String = "/test/project",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messageCount: Int = 5,
        providerId: String? = "openai",
        model: String? = "gpt-4o",
        chatMode: String? = "build"
    ) -> HistoryConversationRow {
        HistoryConversationRow(
            id: id,
            title: title,
            projectId: projectId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            messageCount: messageCount,
            providerId: providerId,
            model: model,
            chatMode: chatMode
        )
    }
}

// MARK: - Tests

@MainActor
@Test func viewModelWithoutServiceReturnsEmpty() async {
    let vm = HistoryDBBrowserViewModel(historyService: nil)
    await vm.reload()

    #expect(vm.totalCount == 0)
    #expect(vm.messageRows.isEmpty)
    #expect(vm.conversationRows.isEmpty)
}

@MainActor
@Test func viewModelLoadsMessageRows() async {
    let mock = MockHistoryQueryService()
    let row1 = HistoryMessageRow.fixture(contentPreview: "Hello")
    let row2 = HistoryMessageRow.fixture(contentPreview: "World")

    mock.messageCount = 2
    mock.messagePages = [0: [row1, row2]]

    let vm = HistoryDBBrowserViewModel(historyService: mock)
    vm.pageSize = 50
    await vm.reload()

    #expect(vm.totalCount == 2)
    #expect(vm.messageRows.count == 2)
    #expect(vm.conversationRows.isEmpty)
}

@MainActor
@Test func viewModelLoadsConversationRows() async {
    let mock = MockHistoryQueryService()
    let conv = HistoryConversationRow.fixture(title: "My Chat")

    mock.conversationCount = 1
    mock.conversationPages = [0: [conv]]

    let vm = HistoryDBBrowserViewModel(historyService: mock)
    vm.selectedMode = .conversations
    await vm.reload()

    #expect(vm.totalCount == 1)
    #expect(vm.conversationRows.count == 1)
    #expect(vm.conversationRows[0].title == "My Chat")
    #expect(vm.messageRows.isEmpty)
}

@MainActor
@Test func viewModelPaginationComputesCorrectly() async {
    let vm = HistoryDBBrowserViewModel(historyService: nil)
    vm.pageSize = 10

    // 初始状态
    #expect(vm.totalPages == 1)
    #expect(vm.currentPage == 1)
    #expect(vm.offset == 0)
}

@MainActor
@Test func viewModelPaginationWithLargeTotal() async {
    let mock = MockHistoryQueryService()
    mock.messageCount = 100

    let vm = HistoryDBBrowserViewModel(historyService: mock)
    vm.pageSize = 50

    // 手动设置 totalCount（通过 reload 间接设置）
    await vm.reload()

    #expect(vm.totalCount == 100)
    #expect(vm.totalPages == 2)
    #expect(vm.offset == 0)

    vm.nextPage()
    #expect(vm.currentPage == 2)
    #expect(vm.offset == 50)

    vm.previousPage()
    #expect(vm.currentPage == 1)
    #expect(vm.offset == 0)
}

@MainActor
@Test func viewModelModeSwitchResetsPage() async {
    let mock = MockHistoryQueryService()
    mock.messageCount = 100
    mock.conversationCount = 30

    let vm = HistoryDBBrowserViewModel(historyService: mock)
    vm.pageSize = 50

    // 前进到第 2 页
    await vm.reload()
    vm.nextPage()
    #expect(vm.currentPage == 2)

    // 切换模式应该重置到第 1 页
    vm.selectedMode = .conversations
    #expect(vm.currentPage == 1)
}

@MainActor
@Test func viewModelPreviousPageGuard() async {
    let vm = HistoryDBBrowserViewModel(historyService: nil)
    vm.pageSize = 50
    #expect(vm.currentPage == 1)

    vm.previousPage()  // 不应该低于 1
    #expect(vm.currentPage == 1)
}

@MainActor
@Test func viewModelNextPageGuard() async {
    let vm = HistoryDBBrowserViewModel(historyService: nil)
    vm.pageSize = 50
    #expect(vm.totalPages == 1)

    vm.nextPage()  // 不应该超过 totalPages
    #expect(vm.currentPage == 1)
}
