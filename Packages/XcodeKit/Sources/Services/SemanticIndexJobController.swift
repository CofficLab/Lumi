import Foundation
import os

public struct SemanticIndexJobResult: Sendable, Equatable {
    public var failureReason: String?
    public var wasCancelled: Bool

    public init(failureReason: String? = nil, wasCancelled: Bool = false) {
        self.failureReason = failureReason
        self.wasCancelled = wasCancelled
    }
}

/// Serializes semantic indexing jobs and manages subprocess lifecycle.
@MainActor
public final class SemanticIndexJobController {
    public static let shared = SemanticIndexJobController()

    public var timeoutInterval: TimeInterval = 45 * 60

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "xcode.semantic-index.job")

    private var currentJobID: UUID?
    private var currentGeneration: UInt64 = 0
    private var runningTask: Task<SemanticIndexJobResult, Never>?
    private var activeProcess: Process?

    private init() {}

    public func beginJob() -> (jobID: UUID, generation: UInt64) {
        currentGeneration &+= 1
        let jobID = UUID()
        currentJobID = jobID
        return (jobID, currentGeneration)
    }

    public func cancelCurrentJob() {
        runningTask?.cancel()
        terminateActiveProcess()
        currentJobID = nil
    }

    public func run(
        generation: UInt64,
        operation: @escaping @Sendable () async -> SemanticIndexJobResult
    ) async -> SemanticIndexJobResult {
        runningTask?.cancel()
        terminateActiveProcess()

        let task = Task {
            await withTaskCancellationHandler {
                await operation()
            } onCancel: {
                Task { @MainActor in
                    self.terminateActiveProcess()
                }
            }
        }
        runningTask = task

        let timeoutResult = await withTaskGroup(of: SemanticIndexJobResult.self) { group in
            group.addTask {
                await task.value
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(self.timeoutInterval * 1_000_000_000))
                return SemanticIndexJobResult(failureReason: "Semantic index timed out", wasCancelled: true)
            }
            let first = await group.next() ?? SemanticIndexJobResult(failureReason: "Semantic index failed")
            group.cancelAll()
            return first
        }

        if generation != currentGeneration {
            return SemanticIndexJobResult(wasCancelled: true)
        }

        runningTask = nil
        terminateActiveProcess()
        return timeoutResult
    }

    public func registerProcess(_ process: Process) {
        activeProcess = process
    }

    public func clearProcessRegistration() {
        activeProcess = nil
    }

    private func terminateActiveProcess() {
        guard let process = activeProcess, process.isRunning else {
            activeProcess = nil
            return
        }
        Self.logger.info("Terminating semantic index subprocess")
        process.terminate()
        activeProcess = nil
    }
}
