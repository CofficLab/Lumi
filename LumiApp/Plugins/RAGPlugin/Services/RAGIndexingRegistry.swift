import Foundation

/// 全局索引状态注册器（线程安全）
///
/// 用于在不进入 `RAGService` actor 的情况下快速判断某项目是否正在索引，
/// 避免发送链路在索引期间因 actor 排队而阻塞。
final class RAGIndexingRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var indexingProjects: Set<String> = []

    func start(projectPath: String) {
        lock.lock()
        indexingProjects.insert(projectPath)
        lock.unlock()
    }

    func finish(projectPath: String) {
        lock.lock()
        indexingProjects.remove(projectPath)
        lock.unlock()
    }

    func contains(projectPath: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return indexingProjects.contains(projectPath)
    }
}
