import Foundation
import SwiftUI
import LanguageServerProtocol

/// LSP 进度通知提供者
@MainActor
final class LSPProgressProvider: ObservableObject {
    
    @Published var activeTasks: [String: ProgressTask] = [:]
    
    func updateProgress(token: String, value: LanguageServerProtocol.LSPAny?) {
        guard case .hash(let dict) = value else { return }
        guard case .string(let kindStr) = dict["kind"] else { return }
        
        switch kindStr {
        case "begin":
            let title = (dict["title"] as? String) ?? ""
            let message = dict["message"] as? String
            let percentage = (dict["percentage"] as? Double).map { Double($0) }
            let cancellable = (dict["cancellable"] as? Bool) == true
            let task = ProgressTask(
                token: token, title: title, message: message,
                percentage: percentage, cancellable: cancellable, state: .inProgress
            )
            activeTasks[token] = task
            
        case "report":
            if var task = activeTasks[token] {
                task.message = (dict["message"] as? String) ?? task.message
                task.percentage = (dict["percentage"] as? Double).map { Double($0) }
                task.state = .inProgress
                activeTasks[token] = task
            }
            
        case "end":
            if var task = activeTasks[token] {
                task.message = (dict["message"] as? String) ?? task.message
                task.state = .completed
                activeTasks[token] = task
                let token = token
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    await MainActor.run { self.activeTasks.removeValue(forKey: token) }
                }
            }
        default: break
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
