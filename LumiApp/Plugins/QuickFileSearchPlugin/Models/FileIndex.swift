import Foundation

/// 文件索引存储
struct FileIndexStore {
    let projectPath: String
    private(set) var files: [FileResult] = []
    private(set) var lastUpdated: Date?

    /// 更新索引
    mutating func update(_ newFiles: [FileResult]) {
        self.files = newFiles
        self.lastUpdated = Date()
    }

    /// 检查是否需要重新索引
    func needsReindex() -> Bool {
        guard let lastUpdated = lastUpdated else { return true }
        // 超过 5 分钟需要重新索引
        return Date().timeIntervalSince(lastUpdated) > 300
    }

    /// 清空索引
    mutating func clear() {
        files = []
        lastUpdated = nil
    }
}
