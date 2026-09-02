import LumiUI
import ProviderToolManager
import SwiftUI

/// 监听一个 Job 的最新快照。每个工具行只订阅自己的 ID，避免把所有 Job
/// 的输出广播给整张消息列表。
@MainActor
final class ToolJobActivityModel: ObservableObject {
    @Published private(set) var job: ToolJob?

    private let manager: (any ToolManagerProviding)?
    private let jobID: String
    private var handle: (any ToolJobObserverHandle)?

    init(manager: (any ToolManagerProviding)?, jobID: String) {
        self.manager = manager
        self.jobID = jobID
        self.job = manager?.job(for: jobID)
        self.handle = manager?.addToolJobObserver { [weak self] event in
            self?.consume(event)
        }
    }

    func cancel() {
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

@MainActor
final class ToolJobGroupActivityModel: ObservableObject {
    @Published private(set) var jobs: [ToolJob]

    private let jobIDs: Set<String>
    private var handle: (any ToolJobObserverHandle)?

    init(manager: (any ToolManagerProviding)?, jobIDs: [String]) {
        self.jobIDs = Set(jobIDs)
        self.jobs = jobIDs.compactMap { manager?.job(for: $0) }
        self.handle = manager?.addToolJobObserver { [weak self] event in
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

struct ToolJobOutputPopover: View {
    let job: ToolJob

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                Text("工具输出")
                    .font(.appCaptionEmphasized)
                Spacer()
                Text(job.toolCall.name)
                    .font(.appMicro)
                    .foregroundColor(.secondary)
            }

            if job.latestOutput.isEmpty {
                AppLoadingOverlay(message: "暂时没有输出", size: .small)
                    .frame(height: 60)
            } else {
                ScrollView(.vertical) {
                    Text(job.latestOutput)
                        .font(.appMonoCaption)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 80, maxHeight: 260)
            }
        }
        .padding(12)
        .frame(width: 360)
        .appSurface(style: .popover, cornerRadius: 12)
    }
}
