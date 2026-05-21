import Foundation
import Combine
import LanguageServerProtocol

/// LSP 进度通知提供者
@MainActor
final class LSPProgressProvider: ObservableObject {

    @Published var activeTasks: [String: ProgressTask] = [:]

    private let staleTaskTimeout: TimeInterval
    private let maxActiveTaskCount: Int
    private let pruningInterval: Duration
    private var pruningTask: Task<Void, Never>?

    init(
        staleTaskTimeout: TimeInterval = 10 * 60,
        maxActiveTaskCount: Int = 32,
        pruningInterval: Duration = .seconds(60)
    ) {
        self.staleTaskTimeout = staleTaskTimeout
        self.maxActiveTaskCount = maxActiveTaskCount
        self.pruningInterval = pruningInterval
    }

    deinit {
        pruningTask?.cancel()
    }

    var hasActiveWork: Bool {
        activeTasks.values.contains { $0.state == .inProgress }
    }

    var primaryActiveTask: ProgressTask? {
        activeTasks.values
            .filter { $0.state == .inProgress }
            .sorted(by: { lhs, rhs in
                let lhsPercentage = lhs.percentage ?? -1
                let rhsPercentage = rhs.percentage ?? -1
                if lhsPercentage != rhsPercentage { return lhsPercentage > rhsPercentage }
                return lhs.token < rhs.token
            })
            .first
    }

    func updateProgress(token: String, value: LanguageServerProtocol.LSPAny?) {
        guard let value else { return }
        guard case .hash(let dict) = value else { return }
        guard let kindVal = dict["kind"], case .string(let kindStr) = kindVal else { return }
        let now = Date()
        pruneStaleTasks(now: now)

        func stringValue(_ key: String) -> String? {
            guard let v = dict[key] else { return nil }
            if case .string(let s) = v { return s }
            return nil
        }

        func numberValue(_ key: String) -> Double? {
            guard let v = dict[key] else { return nil }
            if case .number(let n) = v { return n }
            return nil
        }

        func boolValue(_ key: String) -> Bool {
            guard let v = dict[key] else { return false }
            if case .bool(let b) = v { return b }
            return false
        }

        switch kindStr {
        case "begin":
            let title = stringValue("title") ?? ""
            let message = stringValue("message")
            let percentage = numberValue("percentage")
            let cancellable = boolValue("cancellable")
            let task = ProgressTask(
                token: token, title: title, message: message,
                percentage: percentage, cancellable: cancellable, state: .inProgress,
                updatedAt: now
            )
            activeTasks[token] = task
            enforceTaskLimit()
            schedulePruningIfNeeded()

        case "report":
            if var task = activeTasks[token] {
                task.message = stringValue("message") ?? task.message
                task.percentage = numberValue("percentage") ?? task.percentage
                task.state = .inProgress
                task.updatedAt = now
                activeTasks[token] = task
                enforceTaskLimit()
                schedulePruningIfNeeded()
            }

        case "end":
            if var task = activeTasks[token] {
                task.message = stringValue("message") ?? task.message
                task.state = .completed
                task.updatedAt = now
                activeTasks[token] = task
                let token = token
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    await MainActor.run {
                        guard self.activeTasks[token]?.state == .completed else { return }
                        self.activeTasks.removeValue(forKey: token)
                    }
                }
            }
        default:
            break
        }
    }

    func clear() {
        pruningTask?.cancel()
        pruningTask = nil
        activeTasks.removeAll()
    }

    private func schedulePruningIfNeeded() {
        guard pruningTask == nil else { return }
        let interval = pruningInterval
        pruningTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                await MainActor.run {
                    guard let self else { return }
                    self.pruneStaleTasks(now: Date())
                    self.enforceTaskLimit()
                    if self.activeTasks.isEmpty {
                        self.pruningTask = nil
                    }
                }
                if await MainActor.run(body: { self?.pruningTask == nil }) {
                    return
                }
            }
        }
    }

    private func pruneStaleTasks(now: Date) {
        activeTasks = activeTasks.filter { _, task in
            now.timeIntervalSince(task.updatedAt) <= staleTaskTimeout
        }
    }

    private func enforceTaskLimit() {
        guard activeTasks.count > maxActiveTaskCount else { return }
        let tokensToRemove = activeTasks.values
            .sorted { lhs, rhs in
                if lhs.state != rhs.state {
                    return lhs.state.prunePriority < rhs.state.prunePriority
                }
                return lhs.updatedAt < rhs.updatedAt
            }
            .prefix(activeTasks.count - maxActiveTaskCount)
            .map(\.token)
        tokensToRemove.forEach { activeTasks.removeValue(forKey: $0) }
    }
}

/// 进度任务
struct ProgressTask: Identifiable, Equatable {
    var id: String { token }
    let token: String
    let title: String
    var message: String?
    var percentage: Double?
    let cancellable: Bool
    var state: TaskState
    var updatedAt: Date

    enum TaskState: Equatable {
        case inProgress, completed, cancelled

        var prunePriority: Int {
            switch self {
            case .completed, .cancelled:
                return 0
            case .inProgress:
                return 1
            }
        }
    }
}
