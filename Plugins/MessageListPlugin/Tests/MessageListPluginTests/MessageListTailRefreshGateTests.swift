import Foundation
import Testing
@testable import MessageListPlugin

@MainActor
@Suite("Message list tail refresh gate")
struct MessageListTailRefreshGateTests {
    @Test("Overlapping requests share one active run and one trailing pass")
    func coalescesOverlappingRequests() async {
        let gate = MessageListTailRefreshGate()
        var operationCount = 0

        let owner = Task { @MainActor in
            await gate.run {
                operationCount += 1
                try? await Task.sleep(for: .milliseconds(20))
                return operationCount == 2
            }
        }

        await Task.yield()
        let followerResult = await gate.run {
            Issue.record("Overlapping caller must not start its own operation")
            return true
        }
        let ownerResult = await owner.value

        #expect(followerResult == false)
        #expect(ownerResult == true)
        #expect(operationCount == 2)
    }

    @Test("Sequential requests still refresh independently")
    func runsSequentialRequests() async {
        let gate = MessageListTailRefreshGate()
        var operationCount = 0

        let first = await gate.run {
            operationCount += 1
            return true
        }
        let second = await gate.run {
            operationCount += 1
            return false
        }

        #expect(first == true)
        #expect(second == false)
        #expect(operationCount == 2)
    }

    @Test("Notification filtering keeps refreshes scoped to the selected conversation")
    func filtersConversationEvents() {
        let selected = UUID()

        #expect(MessageListNotificationFilter.shouldHandle(
            eventConversationID: selected,
            selectedConversationID: selected
        ))
        #expect(!MessageListNotificationFilter.shouldHandle(
            eventConversationID: UUID(),
            selectedConversationID: selected
        ))
        #expect(MessageListNotificationFilter.shouldHandle(
            eventConversationID: nil,
            selectedConversationID: selected
        ))
        #expect(!MessageListNotificationFilter.shouldHandle(
            eventConversationID: selected,
            selectedConversationID: nil
        ))
    }
}
