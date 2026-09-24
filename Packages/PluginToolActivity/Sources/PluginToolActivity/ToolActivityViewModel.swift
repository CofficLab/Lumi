import Combine
import Foundation
import ProviderConversation
import ProviderToolManager

@MainActor
final class ToolActivityViewModel: ObservableObject {
    @Published private(set) var jobs: [ToolJob] = []

    private let conversations: any ConversationManaging
    private let toolManager: any ToolManagerProviding
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var jobObserver: (any ToolJobObserverHandle)?

    init(
        conversations: any ConversationManaging,
        toolManager: any ToolManagerProviding
    ) {
        self.conversations = conversations
        self.toolManager = toolManager

        selectedConversationObserver = conversations.addSelectedConversationObserver { [weak self] id in
            self?.setSelectedConversation(id)
        }
        jobObserver = toolManager.addToolJobObserver { [weak self] event in
            self?.handle(event)
        }
        setSelectedConversation(conversations.selectedConversationID)
    }

    func cancel() {
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        jobObserver?.cancel()
        jobObserver = nil
    }

    var selectedConversationID: UUID? {
        conversations.selectedConversationID
    }

    var activeJobs: [ToolJob] {
        jobs.filter { !$0.status.isTerminal }
    }

    var completedJobs: [ToolJob] {
        jobs
            .filter(\.status.isTerminal)
            .sorted {
                if $0.completedAt != $1.completedAt {
                    return ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt)
                }
                return $0.id > $1.id
            }
    }

    var activeCount: Int { activeJobs.count }

    func refresh() {
        guard let conversationID = conversations.selectedConversationID else {
            jobs = []
            return
        }
        jobs = toolManager.jobs(forConversationID: conversationID)
    }

    func displayName(for job: ToolJob) -> String {
        toolManager.displayDescription(for: job.toolCall) ?? job.toolCall.name
    }

    func statusTitle(for status: ToolJobStatus) -> String {
        switch status {
        case .queued:
            return LumiPluginLocalization.string("Queued")
        case .running:
            return LumiPluginLocalization.string("Running")
        case .waitingForUser:
            return LumiPluginLocalization.string("Waiting for you")
        case .cancelling:
            return LumiPluginLocalization.string("Stopping")
        case .completed:
            return LumiPluginLocalization.string("Completed")
        case .failed:
            return LumiPluginLocalization.string("Failed")
        case .cancelled:
            return LumiPluginLocalization.string("Cancelled")
        case .timedOut:
            return LumiPluginLocalization.string("Timed out")
        }
    }

    private func setSelectedConversation(_ id: UUID?) {
        _ = id
        refresh()
    }

    private func handle(_ event: ToolJobEvent) {
        let snapshot: ToolJob
        switch event {
        case .created(let job), .started(let job), .waitingForUser(let job):
            snapshot = job
        case .output(_, _, _, let job), .progress(_, _, let job):
            snapshot = job
        case .completed(_, _, let job), .failed(_, _, let job),
             .cancelled(_, _, let job), .timedOut(_, _, let job):
            snapshot = job
        }

        guard snapshot.conversationID == conversations.selectedConversationID else { return }
        if let index = jobs.firstIndex(where: { $0.id == snapshot.id }) {
            jobs[index] = snapshot
        } else {
            jobs.append(snapshot)
        }
        jobs.sort {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id < $1.id
        }
    }
}
