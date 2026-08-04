import Foundation
import LumiKernel
import os
import SuperLogKit

// MARK: - Child Work

extension AgentTurnRunner {

    @discardableResult
    public func registerChildWork(
        in conversationID: UUID,
        suspensionID: String,
        work: @escaping AgentTurnChildWork
    ) -> Bool {
        pendingChildWorks[conversationID, default: [:]][suspensionID] = work
        return true
    }

    public func activeChildTurnCount(for parentConversationID: UUID) -> Int {
        activeTurnTasks.keys.reduce(into: 0) { count, conversationID in
            guard parentConversationIDs[conversationID] == parentConversationID else { return }
            count += 1
        }
    }

    func startChildWorkIfNeeded(for conversationID: UUID) {
        guard activeChildWorks[conversationID] == nil,
              let suspension = suspensions[conversationID],
              let work = pendingChildWorks[conversationID]?.removeValue(forKey: suspension.suspensionID)
        else { return }

        if pendingChildWorks[conversationID]?.isEmpty == true {
            pendingChildWorks.removeValue(forKey: conversationID)
        }

        let task = Task { @MainActor [weak self] in
            let answer = await work()
            guard !Task.isCancelled, let self else { return }
            activeChildWorks.removeValue(forKey: conversationID)
            let request = AgentTurnResumeRequest(
                suspensionID: suspension.suspensionID,
                answer: answer
            )
            if let messageSender = self.kernel?.messageSender {
                _ = try? await messageSender.resumeTurn(in: conversationID, request: request)
            } else {
                _ = try? await self.resumeTurn(in: conversationID, request: request)
            }
        }
        activeChildWorks[conversationID] = task
    }
}
