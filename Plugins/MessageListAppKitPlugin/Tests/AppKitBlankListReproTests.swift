import AppKit
import Foundation
import Testing
import LumiKernel
@testable import MessageListAppKitPlugin

/// Reproduction for the "conversation opens, loading flashes, list stays
/// blank" report: the coordinator publishes rows and the table measures row
/// heights, yet no row views ever appear on screen.
///
/// Hosts the real `AppKitMessageListViewController` in a real `NSWindow`
/// with in-memory services, then asserts that visible rows actually get
/// cell views with laid-out content.
@Suite(.serialized)
@MainActor
struct AppKitBlankListReproTests {
    @MainActor
    private struct WindowHarness {
        let kernel: LumiKernel
        let conversation = UUID()
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        let controller: AppKitMessageListViewController
        let window: NSWindow

        init(messageCount: Int = 8) throws {
            kernel = LumiKernel()
            for i in 0..<messageCount {
                let message = LumiChatMessage(
                    id: UUID(uuidString: String(format: "%08X-0000-0000-0000-0000000000%02d", i, i % 100)) ?? UUID(),
                    conversationID: conversation,
                    role: i % 2 == 0 ? .user : .assistant,
                    content: "message \(i) — some content to render",
                    createdAt: Date(timeIntervalSinceReferenceDate: 100 + Double(i))
                )
                messages.seed([message], conversationID: conversation)
            }
            conversations.selectedConversationID = conversation
            try kernel.registerService(MessageManaging.self, messages)
            try kernel.registerService(ConversationManaging.self, conversations)
            try kernel.registerService(AgentTurnManaging.self, MockAgentTurnManager())
            try kernel.registerService(MessageStreaming.self, MockMessageStreaming())

            controller = AppKitMessageListViewController(kernel: kernel)
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 824, height: 655),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            // Manual embedding: contentViewController sizing does not run
            // reliably in a headless test runner.
            controller.view.frame = NSRect(x: 0, y: 0, width: 824, height: 655)
            window.contentView?.addSubview(controller.view)
        }

        var tableView: NSTableView? {
            controller.view.subviews
                .compactMap { $0 as? NSScrollView }
                .first?.documentView as? NSTableView
        }

        /// Pumps the run loop so layout/display passes and MainActor tasks run.
        func pump(_ seconds: TimeInterval = 0.05) {
            RunLoop.main.run(until: Date().addingTimeInterval(seconds))
        }
    }

    @Test("打开会话后可见行必须实例化出 cell 视图")
    func visibleRowsGetCellViews() async throws {
        let h = try WindowHarness()
        h.window.orderFront(nil)
        h.window.layoutIfNeeded()
        h.controller.view.layoutSubtreeIfNeeded()
        // Let viewDidLoad's activate task finish, then lay out.
        try await Task.sleep(nanoseconds: 200_000_000)
        h.pump()
        h.window.layoutIfNeeded()
        h.controller.view.layoutSubtreeIfNeeded()
        h.pump()

        let table = try #require(h.tableView)
        #expect(table.numberOfRows == 8)

        // Force the layout/display passes AppKit would run on screen.
        table.layoutSubtreeIfNeeded()
        table.displayIfNeeded()
        h.pump()

        let rowViews = table.subviews.compactMap { $0 as? NSTableRowView }
        #expect(!rowViews.isEmpty, "table has no row views — the list renders blank")

        let cells = rowViews.flatMap(\.subviews)
        #expect(!cells.isEmpty, "row views have no cells — the list renders blank")
        for cell in cells {
            #expect(cell.frame.width > 0 && cell.frame.height > 0, "cell has zero frame: \(cell.frame)")
            #expect(!cell.subviews.isEmpty, "cell has no renderer content")
        }
    }
}
