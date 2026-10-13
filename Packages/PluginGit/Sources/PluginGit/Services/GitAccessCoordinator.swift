import Foundation

/// 按「串行域」划分 libgit2 访问队列。
///
/// `libgit2` 非线程安全：同一仓库的所有访问必须串行。这里为每个串行域
/// （通常是仓库根目录）维护一条**独立**的串行队列，使单个仓库的慢调用 /
/// 卡死调用不再拖住其它仓库的 Git 操作（旧实现为全局单一队列，一次卡死
/// 即阻塞所有会话）。
///
/// 队列对象同时作为 `GitAsyncBridge` 的串行域身份：body 不在队列线程上执行，
/// 队列只负责标识"同一串行域"。
enum GitAccessCoordinator {
    private static let lock = NSLock()
    /// 访问受 `lock` 保护；Swift 6 下静态可变状态需显式标注。
    nonisolated(unsafe) private static var queues: [String: DispatchQueue] = [:]

    /// 取得（或创建）`key` 串行域的队列。同一 key 恒返回同一队列对象。
    static func queue(for key: String) -> DispatchQueue {
        lock.lock()
        defer { lock.unlock() }
        if let existing = queues[key] {
            return existing
        }
        let queue = DispatchQueue(
            label: "com.coffic.lumi.git-access-coordinator.\(key)",
            qos: .userInitiated
        )
        queues[key] = queue
        return queue
    }
}
