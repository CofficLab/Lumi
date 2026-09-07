import LumiUI
import ProviderToolManager
import SwiftUI

/// Observes the latest snapshot for one tool job.
@MainActor
final class ToolJobActivityModel: ObservableObject {
    @Published private(set) var job: ToolJob?

    private let manager: (any ToolManagerProviding)?
    private let toolCallID: String
    private let conversationID: UUID
    private let turnID: UUID?
    private var jobID: String?
    private var handle: (any ToolJobObserverHandle)?

    init(
        manager: (any ToolManagerProviding)?,
        toolCallID: String,
        conversationID: UUID,
        turnID: UUID?
    ) {
        self.manager = manager
        self.toolCallID = toolCallID
        self.conversationID = conversationID
        self.turnID = turnID
        job = manager?.job(
            forToolCallID: toolCallID,
            conversationID: conversationID,
            turnID: turnID
        )
        jobID = job?.id
        handle = manager?.addToolJobObserver { [weak self] event in
            self?.consume(event)
        }
    }

    func cancel() {
        // Keep observing while the manager transitions through `cancelling`
        // and publishes the actual terminal event. Cancelling the observer
        // here would leave the row stuck on the old running snapshot.
        if let jobID { manager?.cancelJob(jobID) }
    }

    private func consume(_ event: ToolJobEvent) {
        let snapshot: ToolJob
        switch event {
        case .created(let value), .started(let value), .waitingForUser(let value):
            snapshot = value
        case .output(let id, _, _, let value), .progress(let id, _, let value),
             .completed(let id, _, let value), .failed(let id, _, let value),
             .cancelled(let id, _, let value), .timedOut(let id, _, let value):
            guard id == jobID else { return }
            snapshot = value
        }
        guard snapshot.id == jobID || (
            snapshot.toolCall.id == toolCallID
                && snapshot.conversationID == conversationID
                && snapshot.turnID == turnID
        ) else { return }
        jobID = snapshot.id
        job = snapshot
    }
}

/// Observes the latest snapshots for a group of tool jobs.
@MainActor
final class ToolJobGroupActivityModel: ObservableObject {
    @Published private(set) var jobs: [ToolJob]

    private let toolCallIDs: Set<String>
    private let conversationID: UUID
    private let turnID: UUID?
    private var handle: (any ToolJobObserverHandle)?

    init(
        manager: (any ToolManagerProviding)?,
        toolCallIDs: [String],
        conversationID: UUID,
        turnID: UUID?
    ) {
        self.toolCallIDs = Set(toolCallIDs)
        self.conversationID = conversationID
        self.turnID = turnID
        jobs = toolCallIDs.compactMap {
            manager?.job(forToolCallID: $0, conversationID: conversationID, turnID: turnID)
        }
        handle = manager?.addToolJobObserver { [weak self] event in
            self?.consume(event)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }

    private func consume(_ event: ToolJobEvent) {
        let snapshot: ToolJob
        switch event {
        case .created(let value), .started(let value), .waitingForUser(let value):
            snapshot = value
        case .output(let id, _, _, let value), .progress(let id, _, let value),
             .completed(let id, _, let value), .failed(let id, _, let value),
             .cancelled(let id, _, let value), .timedOut(let id, _, let value):
            guard id == value.id else { return }
            snapshot = value
        }
        guard toolCallIDs.contains(snapshot.toolCall.id),
              snapshot.conversationID == conversationID,
              snapshot.turnID == turnID else { return }
        if let index = jobs.firstIndex(where: { $0.toolCall.id == snapshot.toolCall.id }) {
            jobs[index] = snapshot
        } else {
            jobs.append(snapshot)
            jobs.sort { $0.createdAt < $1.createdAt }
        }
    }
}
