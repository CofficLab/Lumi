import Foundation

/// 全局索引状态注册器（线程安全）
///
/// 用于在不进入 `RAGService` actor 的情况下快速判断某项目是否正在索引，
/// 避免发送链路在索引期间因 actor 排队而阻塞。
///
/// 同一项目的索引作用域可以重叠（`ensureIndexed` 在 embedding await 处
/// 会让出 actor），因此按项目引用计数：只要还有一个作用域未结束，
/// `contains` 与 `hasAnyIndexing` 就必须保持为真（回归 #1110）。
public final class RAGIndexingRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var indexingCounts: [String: Int] = [:]

    public init() {}

    public func start(projectPath: String) {
        lock.lock()
        indexingCounts[projectPath, default: 0] += 1
        lock.unlock()
    }

    public func finish(projectPath: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let count = indexingCounts[projectPath] else { return }
        if count <= 1 {
            indexingCounts.removeValue(forKey: projectPath)
        } else {
            indexingCounts[projectPath] = count - 1
        }
    }

    public func contains(projectPath: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return indexingCounts[projectPath] != nil
    }

    public func hasAnyIndexing() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !indexingCounts.isEmpty
    }
}
