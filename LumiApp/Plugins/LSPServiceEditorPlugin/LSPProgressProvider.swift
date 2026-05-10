import Foundation
import Combine
import LanguageServerProtocol

/// LSP 进度通知提供者
@MainActor
final class LSPProgressProvider: ObservableObject {

    @Published var activeTasks: [String: ProgressTask] = [:]

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
                percentage: percentage, cancellable: cancellable, state: .inProgress
            )
            activeTasks[token] = task

        case "report":
            if var task = activeTasks[token] {
                task.message = stringValue("message") ?? task.message
                task.percentage = numberValue("percentage") ?? task.percentage
                task.state = .inProgress
                activeTasks[token] = task
            }

        case "end":
            if var task = activeTasks[token] {
                task.message = stringValue("message") ?? task.message
                task.state = .completed
                activeTasks[token] = task
                let token = token
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    await MainActor.run { self.activeTasks.removeValue(forKey: token) }
                }
            }
        default:
            break
        }
    }

    func clear() { activeTasks.removeAll() }
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

    enum TaskState: Equatable {
        case inProgress, completed, cancelled
    }
}
