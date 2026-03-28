import Foundation
import SwiftData

// MARK: - AsyncSemaphore

/// 异步信号量，用于控制并发
private actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func wait() async {
        if value > 0 {
            value -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    nonisolated func signal() {
        Task {
            await _signal()
        }
    }

    private func _signal() {
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}

// MARK: - BackgroundAgentTaskWorker

/// Worker 负责从数据库中获取任务并执行
/// 采用事件驱动 + 轮询混合模式
actor BackgroundAgentTaskWorker {
    private unowned let store: TaskStoreProtocol
    private var isRunning = false
    private var workerTask: Task<Void, Never>?
    private let maxConcurrentTasks = 2
    private var runningTaskCount = 0
    private let semaphore = AsyncSemaphore(value: 2)

    init(store: TaskStoreProtocol) {
        self.store = store
    }

    // MARK: - Lifecycle

    nonisolated func start() {
        Task { await _start() }
    }

    private func _start() {
        guard !isRunning else { return }
        isRunning = true
        
        workerTask = Task.detached { [weak self] in
            await self?.mainLoop()
        }
        
        Task { [weak self] in
            self?.observeTaskCreation()
        }
    }

    // MARK: - Main Loop

    private func mainLoop() async {
        while !Task.isCancelled {
            let executed = await fetchAndExecuteNextTask()
            
            if !executed {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            
            await waitForAvailableSlot()
        }
    }

    private func waitForAvailableSlot() async {
        while runningTaskCount >= maxConcurrentTasks && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    // MARK: - Task Execution

    private func fetchAndExecuteNextTask() async -> Bool {
        await semaphore.wait()
        
        guard let taskId = await store.claimNextPendingTask() else {
            semaphore.signal()
            return false
        }
        
        runningTaskCount += 1
        
        Task.detached { [weak self, taskId] in
            await self?.executeTask(taskId: taskId)
        }
        
        return true
    }

    private func executeTask(taskId: UUID) async {
        defer {
            runningTaskCount -= 1
            semaphore.signal()
        }
        
        do {
            let result = try await store.performTask(taskId: taskId)
            
            await store.updateTask(
                id: taskId,
                status: .succeeded,
                resultSummary: result.summary,
                errorDescription: nil,
                finishedAt: Date()
            )
        } catch {
            await store.updateTask(
                id: taskId,
                status: .failed,
                resultSummary: nil,
                errorDescription: error.localizedDescription,
                finishedAt: Date()
            )
        }
    }

    // MARK: - Event Observation

    private nonisolated func observeTaskCreation() {
        Task { @MainActor in
            _ = NotificationCenter.default.addObserver(
                forName: .backgroundAgentTaskDidCreate,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { [weak self] in
                    await self?.fetchAndExecuteNextTask()
                }
            }
        }
    }
}
