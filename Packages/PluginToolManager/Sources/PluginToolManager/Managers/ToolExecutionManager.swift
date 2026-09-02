import Foundation
import KitAgentTool
import ProviderToolManager

/// Tool Job 的 MainActor 控制面。
///
/// 负责保存可观察快照、发布事件和等待者；真正的工具调用由
/// `ToolExecutionRuntime` 持有的 detached Task 执行。
@MainActor
final class ToolExecutionManager {
    private static let maxOutputBytes = 64 * 1024
    private static let maxParallelReadOnlyJobs = 4

    private struct ExecutionScope: Hashable {
        let conversationID: UUID
        let turnID: UUID?
    }

    private struct ExecutionMetadata {
        let scope: ExecutionScope
        let capability: ToolExecutionCapability
    }

    private struct PendingExecution {
        let tool: any SuperAgentTool
        let arguments: [String: ToolArgument]
    }

    private let runtime = ToolExecutionRuntime()
    private var jobsByID: [String: ToolJob] = [:]
    private var resultsByID: [String: ToolCallResult] = [:]
    private var waiters: [String: [CheckedContinuation<ToolCallResult, Never>]] = [:]
    private var observers: [UUID: (ToolJobEvent) -> Void] = [:]
    private var submissionOrder: [String] = []
    private var pendingExecutions: [String: PendingExecution] = [:]
    private var executionMetadata: [String: ExecutionMetadata] = [:]
    private var runningJobIDs: Set<String> = []

    @discardableResult
    func addObserver(
        _ callback: @escaping (ToolJobEvent) -> Void
    ) -> any ToolJobObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ToolJobObserverHandleImpl { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    @discardableResult
    func submit(
        _ toolCalls: [ToolCall],
        policy: ToolExecutionPolicy,
        conversationID: UUID,
        turnID: UUID?,
        toolResolver: @escaping (String) -> (any SuperAgentTool)?
    ) -> [ToolJob] {
        guard policy == .autoExecute else { return [] }

        return toolCalls.map { toolCall in
            if let existing = jobsByID[toolCall.id] {
                return existing
            }

            guard let tool = toolResolver(toolCall.name) else {
                let result = ToolCallResult(
                    content: "Tool not found: \(toolCall.name)",
                    isError: true
                )
                return finishImmediately(
                    toolCall: toolCall,
                    conversationID: conversationID,
                    turnID: turnID,
                    result: result,
                    status: .failed,
                    errorMessage: result.content
                )
            }

            let arguments: [String: ToolArgument]
            do {
                arguments = try ToolArgumentCoding.decode(toolCall.arguments)
            } catch {
                let result = ToolCallResult(
                    content: "Tool execution failed: \(error.localizedDescription)",
                    isError: true
                )
                return finishImmediately(
                    toolCall: toolCall,
                    conversationID: conversationID,
                    turnID: turnID,
                    result: result,
                    status: .failed,
                    errorMessage: error.localizedDescription
                )
            }

            let job = ToolJob(
                conversationID: conversationID,
                turnID: turnID,
                toolCall: toolCall
            )
            jobsByID[job.id] = job
            submissionOrder.append(job.id)
            executionMetadata[job.id] = ExecutionMetadata(
                scope: ExecutionScope(conversationID: conversationID, turnID: turnID),
                capability: tool.executionCapability
            )
            pendingExecutions[job.id] = PendingExecution(tool: tool, arguments: arguments)
            emit(.created(job))
            schedule()
            return jobsByID[job.id] ?? job
        }
    }

    func job(for jobID: String) -> ToolJob? {
        jobsByID[jobID]
    }

    func jobs(for turnID: UUID) -> [ToolJob] {
        jobsByID.values
            .filter { $0.turnID == turnID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func waitForResult(jobID: String) async -> ToolCallResult? {
        if let result = resultsByID[jobID] {
            return result
        }
        guard jobsByID[jobID] != nil else { return nil }
        return await withCheckedContinuation { continuation in
            if let result = resultsByID[jobID] {
                continuation.resume(returning: result)
            } else {
                waiters[jobID, default: []].append(continuation)
            }
        }
    }

    func cancelJob(_ jobID: String) {
        guard let job = jobsByID[jobID], !job.status.isTerminal else { return }
        Task { await runtime.cancel(jobID: jobID) }
        let result = ToolCallResult(content: "Tool execution cancelled.", isError: true)
        finish(
            jobID: jobID,
            result: result,
            status: .cancelled,
            errorMessage: result.content
        )
        if !runningJobIDs.contains(jobID) {
            releaseExecution(jobID: jobID)
        }
    }

    func cancelJobs(forTurnID turnID: UUID) {
        for job in jobsByID.values where job.turnID == turnID {
            cancelJob(job.id)
        }
    }

    func cancelJobs(forConversationID conversationID: UUID) {
        for job in jobsByID.values where job.conversationID == conversationID {
            cancelJob(job.id)
        }
    }

    private func start(
        job: ToolJob,
        tool: any SuperAgentTool,
        arguments: [String: ToolArgument]
    ) {
        pendingExecutions.removeValue(forKey: job.id)
        runningJobIDs.insert(job.id)

        var runningJob = job
        runningJob.status = .running
        runningJob.startedAt = Date()
        runningJob.updatedAt = Date()
        jobsByID[job.id] = runningJob
        emit(.started(runningJob))

        let bridge = ToolJobEventBridge(owner: self)
        let context = ToolExecutionContext(
            jobID: job.id,
            conversationID: job.conversationID,
            turnID: job.turnID,
            isCancelled: { Task.isCancelled },
            reportOutput: { stream, chunk in
                await bridge.reportOutput(jobID: job.id, stream: stream, chunk: chunk)
            },
            reportProgress: { progress in
                await bridge.reportProgress(jobID: job.id, progress: progress)
            }
        )

        Task { [weak self] in
            guard let self, self.jobsByID[job.id]?.status.isTerminal == false else {
                self?.releaseExecution(jobID: job.id)
                return
            }
            await self.runtime.start(jobID: job.id) {
                let startedAt = Date()
                do {
                    let output = try await tool.executeResult(
                        context: context,
                        arguments: arguments
                    )
                    let result = ToolCallResult(
                        content: output.content,
                        images: output.images,
                        isError: output.isError,
                        executedAt: Date(),
                        duration: Date().timeIntervalSince(startedAt),
                        awaitingUserResponse: output.awaitingUserResponse,
                        interactionState: output.interactionState
                    )
                    return .completed(result)
                } catch {
                    if Task.isCancelled {
                        return .cancelled(error.localizedDescription)
                    }
                    return .failed(error.localizedDescription)
                }
            }

            if self.jobsByID[job.id]?.status.isTerminal == true {
                await self.runtime.cancel(jobID: job.id)
            }
            guard let outcome = await self.runtime.wait(for: job.id) else {
                self.releaseExecution(jobID: job.id)
                return
            }
            self.apply(outcome: outcome, jobID: job.id)
        }
    }

    private func apply(outcome: ToolExecutionOutcome, jobID: String) {
        if let job = jobsByID[jobID], !job.status.isTerminal {
            switch outcome {
            case .completed(let result):
                finish(jobID: jobID, result: result, status: .completed, errorMessage: nil)
            case .failed(let message):
                let result = ToolCallResult(
                    content: "Tool execution failed: \(message)",
                    isError: true
                )
                finish(jobID: jobID, result: result, status: .failed, errorMessage: message)
            case .cancelled(let message):
                let result = ToolCallResult(content: "Tool execution cancelled.", isError: true)
                finish(jobID: jobID, result: result, status: .cancelled, errorMessage: message)
            }
        }
        releaseExecution(jobID: jobID)
    }

    /// Starts every queued job that is safe to run now. Read-only jobs may
    /// share a turn, while side-effecting and interactive jobs form strict
    /// barriers in submission order.
    private func schedule() {
        var madeProgress = true
        while madeProgress {
            madeProgress = false

            for jobID in submissionOrder {
                guard let job = jobsByID[jobID],
                      job.status == .queued,
                      let pending = pendingExecutions[jobID],
                      let metadata = executionMetadata[jobID],
                      canStart(jobID: jobID, metadata: metadata)
                else { continue }

                start(job: job, tool: pending.tool, arguments: pending.arguments)
                madeProgress = true
            }
        }
    }

    private func canStart(jobID: String, metadata: ExecutionMetadata) -> Bool {
        switch metadata.capability {
        case .parallelReadOnly:
            guard activeReadOnlyJobCount(in: metadata.scope) < Self.maxParallelReadOnlyJobs else {
                return false
            }
            return !hasEarlierBarrier(before: jobID, in: metadata.scope)
        case .serialSideEffect, .interactive:
            return !hasEarlierUnfinishedJob(before: jobID, in: metadata.scope)
        }
    }

    private func activeReadOnlyJobCount(in scope: ExecutionScope) -> Int {
        runningJobIDs.reduce(into: 0) { count, jobID in
            guard let metadata = executionMetadata[jobID],
                  metadata.scope == scope,
                  metadata.capability == .parallelReadOnly
            else { return }
            count += 1
        }
    }

    private func hasEarlierBarrier(before jobID: String, in scope: ExecutionScope) -> Bool {
        for earlierID in submissionOrder.prefix(while: { $0 != jobID }) {
            guard let earlierJob = jobsByID[earlierID],
                  !earlierJob.status.isTerminal,
                  let metadata = executionMetadata[earlierID],
                  metadata.scope == scope
            else { continue }

            if metadata.capability == .serialSideEffect || metadata.capability == .interactive {
                return true
            }
        }
        return false
    }

    private func hasEarlierUnfinishedJob(before jobID: String, in scope: ExecutionScope) -> Bool {
        for earlierID in submissionOrder.prefix(while: { $0 != jobID }) {
            guard let earlierJob = jobsByID[earlierID],
                  !earlierJob.status.isTerminal,
                  let metadata = executionMetadata[earlierID],
                  metadata.scope == scope
            else { continue }
            return true
        }
        return false
    }

    private func releaseExecution(jobID: String) {
        pendingExecutions.removeValue(forKey: jobID)
        runningJobIDs.remove(jobID)
        executionMetadata.removeValue(forKey: jobID)
        schedule()
    }

    private func finishImmediately(
        toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?,
        result: ToolCallResult,
        status: ToolJobStatus,
        errorMessage: String?
    ) -> ToolJob {
        let now = Date()
        let job = ToolJob(
            conversationID: conversationID,
            turnID: turnID,
            toolCall: toolCall,
            status: status,
            createdAt: now,
            updatedAt: now,
            completedAt: now,
            errorMessage: errorMessage
        )
        jobsByID[job.id] = job
        resultsByID[job.id] = result
        emit(.created(job))
        emitTerminal(jobID: job.id, status: status, result: result, snapshot: job)
        return job
    }

    private func finish(
        jobID: String,
        result: ToolCallResult,
        status: ToolJobStatus,
        errorMessage: String?
    ) {
        guard var job = jobsByID[jobID], !job.status.isTerminal else { return }
        job.status = status
        job.updatedAt = Date()
        job.completedAt = Date()
        job.errorMessage = errorMessage
        jobsByID[jobID] = job
        resultsByID[jobID] = result
        emitTerminal(jobID: jobID, status: status, result: result, snapshot: job)
        let continuations = waiters.removeValue(forKey: jobID) ?? []
        for continuation in continuations {
            continuation.resume(returning: result)
        }
    }

    private func emitTerminal(
        jobID: String,
        status: ToolJobStatus,
        result: ToolCallResult,
        snapshot: ToolJob
    ) {
        switch status {
        case .completed:
            emit(.completed(jobID: jobID, result: result, snapshot: snapshot))
        case .failed:
            emit(.failed(jobID: jobID, result: result, snapshot: snapshot))
        case .cancelled:
            emit(.cancelled(jobID: jobID, result: result, snapshot: snapshot))
        case .timedOut:
            emit(.timedOut(jobID: jobID, result: result, snapshot: snapshot))
        case .queued, .running, .waitingForUser:
            break
        }
    }

    private func emit(_ event: ToolJobEvent) {
        for observer in observers.values {
            observer(event)
        }
    }

    fileprivate func recordOutput(
        jobID: String,
        stream: ToolExecutionOutputStream,
        chunk: String
    ) {
        guard var job = jobsByID[jobID], !job.status.isTerminal else { return }
        let data = Data(chunk.utf8)
        job.outputByteCount += data.count
        let combined = Data(job.latestOutput.utf8) + data
        job.latestOutput = String(
            decoding: combined.suffix(Self.maxOutputBytes),
            as: UTF8.self
        )
        job.updatedAt = Date()
        jobsByID[jobID] = job
        let outputStream: ToolOutputStream = stream == .stdout ? .stdout : .stderr
        emit(.output(
            jobID: jobID,
            stream: outputStream,
            chunk: chunk,
            snapshot: job
        ))
    }

    fileprivate func recordProgress(
        jobID: String,
        progress: ToolExecutionProgress
    ) {
        guard let job = jobsByID[jobID], !job.status.isTerminal else { return }
        emit(.progress(
            jobID: jobID,
            progress: ToolJobProgress(
                message: progress.message,
                completed: progress.completed,
                total: progress.total,
                fraction: progress.fraction
            ),
            snapshot: job
        ))
    }
}

private final class ToolJobEventBridge: @unchecked Sendable {
    private weak var owner: ToolExecutionManager?

    init(owner: ToolExecutionManager) {
        self.owner = owner
    }

    func reportOutput(
        jobID: String,
        stream: ToolExecutionOutputStream,
        chunk: String
    ) async {
        await MainActor.run { [weak self] in
            self?.owner?.recordOutput(jobID: jobID, stream: stream, chunk: chunk)
        }
    }

    func reportProgress(
        jobID: String,
        progress: ToolExecutionProgress
    ) async {
        await MainActor.run { [weak self] in
            self?.owner?.recordProgress(jobID: jobID, progress: progress)
        }
    }
}

@MainActor
private final class ToolJobObserverHandleImpl: ToolJobObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}
