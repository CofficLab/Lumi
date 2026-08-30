import Foundation

/// 记录最近一次自动注入的检索，避免紧接着的同查询工具调用重复输出。
///
/// 这是插件实例级的短期状态，不写入磁盘，也不跨插件生命周期保留。
@MainActor
final class ProjectRAGSearchMemory {
    private struct Entry {
        let projectPath: String
        let query: String
        let createdAt: Date
    }

    private let ttl: TimeInterval = 2
    private var latestEntry: Entry?

    func recordAutomaticSearch(query: String, projectPath: String) {
        latestEntry = Entry(projectPath: projectPath, query: normalized(query), createdAt: Date())
    }

    func consumeRecentAutomaticSearch(query: String, projectPath: String) -> Bool {
        guard let latestEntry else { return false }
        guard Date().timeIntervalSince(latestEntry.createdAt) <= ttl else {
            self.latestEntry = nil
            return false
        }
        guard latestEntry.projectPath == projectPath, latestEntry.query == normalized(query) else {
            return false
        }
        self.latestEntry = nil
        return true
    }

    private func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
