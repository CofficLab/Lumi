import LumiUI
import ProviderToolManager
import SwiftUI

/// Observes the latest snapshot for one tool job.
@MainActor
final class ToolJobActivityModel: ObservableObject {
    @Published private(set) var job: ToolJob?

    private let manager: (any ToolManagerProviding)?
    private let jobID: String
    private var handle: (any ToolJobObserverHandle)?

    init(manager: (any ToolManagerProviding)?, jobID: String) {
        self.manager = manager
        self.jobID = jobID
        job = manager?.job(for: jobID)
        handle = manager?.addToolJobObserver { [weak self] event in
            self?.consume(event)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
        manager?.cancelJob(jobID)
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
        guard snapshot.id == jobID else { return }
        job = snapshot
    }
}

/// Observes the latest snapshots for a group of tool jobs.
@MainActor
final class ToolJobGroupActivityModel: ObservableObject {
    @Published private(set) var jobs: [ToolJob]

    private let jobIDs: Set<String>
    private var handle: (any ToolJobObserverHandle)?

    init(manager: (any ToolManagerProviding)?, jobIDs: [String]) {
        self.jobIDs = Set(jobIDs)
        jobs = jobIDs.compactMap { manager?.job(for: $0) }
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
            guard jobIDs.contains(id) else { return }
            snapshot = value
        }
        guard jobIDs.contains(snapshot.id) else { return }
        if let index = jobs.firstIndex(where: { $0.id == snapshot.id }) {
            jobs[index] = snapshot
        } else {
            jobs.append(snapshot)
            jobs.sort { $0.createdAt < $1.createdAt }
        }
    }
}
