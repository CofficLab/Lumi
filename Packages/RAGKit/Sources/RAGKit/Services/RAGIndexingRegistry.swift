import Foundation

/// 全局索引状态注册器（线程安全）
///
/// 用于在不进入 `RAGService` actor 的情况下快速判断某项目是否正在索引，
/// 避免发送链路在索引期间因 actor 排队而阻塞。
public final class RAGIndexingRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var indexingProjects: Set<String> = []

    public init() {}

    public func start(projectPath: String) {
        lock.lock()
        indexingProjects.insert(projectPath)
        lock.unlock()
    }

    public func finish(projectPath: String) {
        lock.lock()
        indexingProjects.remove(projectPath)
        lock.unlock()
    }

    public func contains(projectPath: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return indexingProjects.contains(projectPath)
    }

    public func hasAnyIndexing() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !indexingProjects.isEmpty
    }
}
