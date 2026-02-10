import Foundation
import Combine
import SwiftUI

enum TaskStatus: Equatable {
    case pending
    case running
    case completed
    case failed(String)
    case cancelled
}

struct BackgroundTask: Identifiable, Equatable {
    let id: UUID
    let title: String
    var progress: Double // 0.0 - 1.0
    var status: TaskStatus
    let startTime: Date
    var endTime: Date?
    var canCancel: Bool
    var priority: TaskPriority
}

@MainActor
class TaskService: ObservableObject {
    static let shared = TaskService()
    
    @Published var tasks: [BackgroundTask] = []
    
    private init() {}
    
    /// Register and start a tracked task
    /// - Parameters:
    ///   - title: Task display title
    ///   - priority: Task priority
    ///   - operation: The async operation to perform
    func run<T: Sendable>(
        title: String,
        priority: TaskPriority = .medium,
        canCancel: Bool = true,
        operation: @escaping @Sendable (_ updateProgress: @escaping @Sendable (Double) -> Void) async throws -> T
    ) async throws -> T {
        let id = UUID()
        let taskInfo = BackgroundTask(
            id: id,
            title: title,
            progress: 0.0,
            status: .running,
            startTime: Date(),
            canCancel: canCancel,
            priority: priority
        )
        
        self.tasks.append(taskInfo)
        
        let updateProgress: @Sendable (Double) -> Void = { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.updateProgress(id: id, progress: progress)
            }
        }
        
        do {
            // Run the operation with the specified priority
            let result = try await Task.detached(priority: priority) {
                try await operation(updateProgress)
            }.value
            
            self.completeTask(id: id)
            return result
        } catch {
            if error is CancellationError {
                self.cancelTask(id: id)
            } else {
                self.failTask(id: id, error: error)
            }
            throw error
        }
    }
    
    func updateProgress(id: UUID, progress: Double) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].progress = progress
        }
    }
    
    func completeTask(id: UUID) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].status = .completed
            tasks[index].progress = 1.0
            tasks[index].endTime = Date()
            
            // Auto-remove completed tasks after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                self.removeTask(id: id)
            }
        }
    }
    
    func failTask(id: UUID, error: Error) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].status = .failed(error.localizedDescription)
            tasks[index].endTime = Date()
        }
    }
    
    func cancelTask(id: UUID) {
         if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].status = .cancelled
            tasks[index].endTime = Date()
            
             // Auto-remove cancelled tasks
             Task {
                 try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                 self.removeTask(id: id)
             }
        }
    }
    
    func removeTask(id: UUID) {
        withAnimation {
            tasks.removeAll { $0.id == id }
        }
    }
}
