import Foundation

/// 项目问题存储
///
/// 负责持久化和查询扫描器发现的项目问题。
/// 使用 JSON 文件存储，位于插件专属目录下。
actor ProjectIssueStore {
    static let shared = ProjectIssueStore()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let issuesFileURL: URL
    private var issues: [ProjectIssue] = []

    // MARK: - Initialization

    private init() {
        let dir = AppConfig.getDBFolderURL()
            .appendingPathComponent("ProjectIssueScanner", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.issuesFileURL = dir.appendingPathComponent("issues.json")
        self.issues = (try? loadFromDisk()) ?? []
    }

    // MARK: - Public API

    /// 添加问题（自动去重）
    func upsert(_ issue: ProjectIssue) {
        if let index = issues.firstIndex(where: { $0.dedupeKey == issue.dedupeKey }) {
            issues[index] = issue
        } else {
            issues.append(issue)
        }
        try? persist()
    }

    /// 批量添加（自动去重）
    func upsertBatch(_ newIssues: [ProjectIssue]) {
        for issue in newIssues {
            if let index = issues.firstIndex(where: { $0.dedupeKey == issue.dedupeKey }) {
                issues[index] = issue
            } else {
                issues.append(issue)
            }
        }
        try? persist()
    }

    /// 获取所有未解决的问题
    func fetchOpen() -> [ProjectIssue] {
        issues.filter(\.isOpen)
    }

    /// 获取所有问题
    func fetchAll() -> [ProjectIssue] {
        issues
    }

    /// 按文件路径筛选未解决的问题
    func fetchOpen(forFilePath path: String) -> [ProjectIssue] {
        issues.filter { $0.isOpen && $0.filePath == path }
    }

    /// 按严重程度筛选未解决的问题
    func fetchOpen(severity: ProjectIssueSeverity) -> [ProjectIssue] {
        issues.filter { $0.isOpen && $0.severity == severity }
    }

    /// 更新问题状态
    func updateStatus(id: UUID, status: ProjectIssueStatus) {
        guard let index = issues.firstIndex(where: { $0.id == id }) else { return }
        issues[index].status = status
        issues[index].updatedAt = Date()
        try? persist()
    }

    /// 移除指定文件的所有问题（文件已删除或重命名时使用）
    func removeIssues(forFilePath path: String) {
        issues.removeAll { $0.filePath == path }
        try? persist()
    }

    /// 清空所有问题
    func clearAll() {
        issues.removeAll()
        try? persist()
    }

    /// 未解决问题的数量
    func openCount() -> Int {
        issues.filter(\.isOpen).count
    }

    // MARK: - Private

    private func loadFromDisk() throws -> [ProjectIssue] {
        let data = try Data(contentsOf: issuesFileURL)
        return try JSONDecoder().decode([ProjectIssue].self, from: data)
    }

    private func persist() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(issues)
        try data.write(to: issuesFileURL, options: [.atomic])
    }
}
