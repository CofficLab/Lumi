import LumiUI
import ProviderToolManager
import SwiftUI

/// Observes the latest snapshot for one tool job.
@MainActor
final class ToolJobActivityModel: ObservableObject {
    @Published private(set) var job: ToolJob?

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
