import Foundation
import SwiftUI
import LanguageServerProtocol

/// LSP 进度通知提供者
@MainActor
final class LSPProgressProvider: ObservableObject {

    @Published var activeTasks: [String: ProgressTask] = [:]

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

// MARK: - UI View

struct LSPProgressIndicatorView: View {
    @ObservedObject var provider: LSPProgressProvider

    var body: some View {
        ForEach(provider.activeTasks.values.sorted(by: { $0.token < $1.token })) { task in
            HStack(spacing: 8) {
                if task.state == .inProgress {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title).font(.system(size: 12))
                    if let message = task.message {
                        Text(message).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if let percentage = task.percentage {
                    Text("\(Int(percentage))%").font(.system(size: 11)).monospacedDigit()
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
        }
    }
}
