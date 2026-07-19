import Testing
import Foundation
@testable import HistoryDBStatusBarPlugin
@testable import LumiKernel

// MARK: - BrowserViewModel Tests

@MainActor
struct BrowserViewModelTests {
    @Test func pluginPolicyIsAlwaysOn() {
        #expect(HistoryDBStatusBarPlugin.policy == .alwaysOn)
        #expect(HistoryDBStatusBarPlugin.info.id.isEmpty == false)
    }

    
    @Test func viewModelWithoutServiceReturnsEmpty() async {
        let vm = BrowserViewModel(historyService: nil)
        await vm.reload()

        #expect(vm.totalCount == 0)
        #expect(vm.messageRows.isEmpty)
        #expect(vm.conversationRows.isEmpty)
    }

    @Test func viewModelLoadsMessageRows() async {
        let mock = MockHistoryQueryService()
        let row1 = HistoryMessageRow.fixture(contentPreview: "Hello")
        let row2 = HistoryMessageRow.fixture(contentPreview: "World")

        mock.messageCount = 2
        mock.messagePages = [0: [row1, row2]]

        let vm = BrowserViewModel(historyService: mock)
        vm.pageSize = 50
        await vm.reload()

        #expect(vm.totalCount == 2)
        #expect(vm.messageRows.count == 2)
        #expect(vm.conversationRows.isEmpty)
    }

    @Test func viewModelLoadsConversationRows() async {
        let mock = MockHistoryQueryService()
        let conv = HistoryConversationRow.fixture(title: "My Chat")

        mock.conversationCount = 1
        mock.conversationPages = [0: [conv]]

        let vm = BrowserViewModel(historyService: mock)
        vm.selectedMode = .conversations
        await vm.reload()

        #expect(vm.totalCount == 1)
        #expect(vm.conversationRows.count == 1)
        #expect(vm.conversationRows[0].title == "My Chat")
        #expect(vm.messageRows.isEmpty)
    }

    @Test func viewModelPaginationComputesCorrectly() async {
        let vm = BrowserViewModel(historyService: nil)
        vm.pageSize = 10

        #expect(vm.totalPages == 1)
        #expect(vm.currentPage == 1)
        #expect(vm.offset == 0)
    }

    @Test func viewModelPaginationWithLargeTotal() async {
        let mock = MockHistoryQueryService()
        mock.messageCount = 100

        let vm = BrowserViewModel(historyService: mock)
        vm.pageSize = 50
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

    @Test func viewModelModeSwitchResetsPage() async {
        let mock = MockHistoryQueryService()
        mock.messageCount = 100
        mock.conversationCount = 30

        let vm = BrowserViewModel(historyService: mock)
        vm.pageSize = 50

        await vm.reload()
        vm.nextPage()
        #expect(vm.currentPage == 2)

        vm.selectedMode = .conversations
        #expect(vm.currentPage == 1)
    }

    @Test func viewModelPreviousPageGuard() async {
        let vm = BrowserViewModel(historyService: nil)
        vm.pageSize = 50
        #expect(vm.currentPage == 1)

        vm.previousPage()
        #expect(vm.currentPage == 1)
    }

    @Test func viewModelNextPageGuard() async {
        let vm = BrowserViewModel(historyService: nil)
        vm.pageSize = 50
        #expect(vm.totalPages == 1)

        vm.nextPage()
        #expect(vm.currentPage == 1)
    }

    @Test func viewModelClampsInvalidPageSizeBeforeQuerying() async {
        let mock = MockHistoryQueryService()
        mock.messageCount = 1000

        let vm = BrowserViewModel(historyService: mock)
        vm.pageSize = 0
        await vm.reload()

        #expect(mock.messagePageRequests.last?.limit == 1)
        #expect(vm.totalPages == 1000)

        vm.pageSize = 10_000
        await vm.reload()

        #expect(mock.messagePageRequests.last?.limit == 500)
        #expect(vm.totalPages == 2)
    }

    @Test func viewModelClampsCurrentPageAfterCountShrinks() async {
        let mock = MockHistoryQueryService()
        mock.messageCount = 120

        let vm = BrowserViewModel(historyService: mock)
        vm.pageSize = 50
        await vm.reload()
        vm.nextPage()
        vm.nextPage()
        #expect(vm.currentPage == 3)

        mock.messageCount = 20
        await vm.reload()

        #expect(vm.currentPage == 1)
        #expect(mock.messagePageRequests.last?.offset == 0)
    }

    @Test func viewModelIgnoresStaleReloadAfterModeSwitch() async {
        let mock = MockHistoryQueryService()
        let message = HistoryMessageRow.fixture(contentPreview: "stale message")
        let conversation = HistoryConversationRow.fixture(title: "Current Chat")

        mock.messageCount = 1
        mock.conversationCount = 1
        mock.messagePages = [0: [message]]
        mock.conversationPages = [0: [conversation]]
        mock.messagePageDelayNanoseconds = 100_000_000

        let vm = BrowserViewModel(historyService: mock)
        let staleReload = Task { await vm.reload() }
        try? await Task.sleep(nanoseconds: 10_000_000)

        vm.selectedMode = .conversations
        await vm.reload()
        await staleReload.value

        #expect(vm.selectedMode == .conversations)
        #expect(vm.messageRows.isEmpty)
        #expect(vm.conversationRows.map(\.title) == ["Current Chat"])
    }
}
