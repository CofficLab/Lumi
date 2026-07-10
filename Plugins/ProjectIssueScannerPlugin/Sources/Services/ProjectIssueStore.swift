import Foundation
import LumiCoreKit

/// 项目问题存储
///
/// 负责持久化和查询扫描器发现的项目问题。
/// 使用 JSON 文件存储，位于插件专属目录下。
public actor ProjectIssueStore {
    public static let shared = ProjectIssueStore()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let issuesFileURL: URL
    private var issues: [ProjectIssue] = []

    // MARK: - Initialization

    private init() {
        let dir = ProjectIssueScannerRuntimeBridge.dataDirectory
            ?? FileManager.default.temporaryDirectory
                .appendingPathComponent("ProjectIssueScanner", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.issuesFileURL = dir.appendingPathComponent("issues.json")
        self.issues = (try? Self.loadFromDisk(from: issuesFileURL)) ?? []
    }

    init(issuesFileURL: URL) {
        let dir = issuesFileURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.issuesFileURL = issuesFileURL
        self.issues = (try? Self.loadFromDisk(from: issuesFileURL)) ?? []
    }

    // MARK: - Public API

    /// 添加问题（自动去重）
    public func upsert(_ issue: ProjectIssue) throws {
        if let index = issues.firstIndex(where: { $0.dedupeKey == issue.dedupeKey }) {
            issues[index] = issue
        } else {
            issues.append(issue)
        }
        try persist()
    }

    /// 批量添加（自动去重）
    public func upsertBatch(_ newIssues: [ProjectIssue]) throws {
        for issue in newIssues {
            if let index = issues.firstIndex(where: { $0.dedupeKey == issue.dedupeKey }) {
                issues[index] = issue
            } else {
                issues.append(issue)
            }
        }
        try persist()
    }

    /// 获取所有未解决的问题
    public func fetchOpen() -> [ProjectIssue] {
        issues.filter(\.isOpen)
    }

    /// 获取指定项目所有未解决的问题
    public func fetchOpen(projectPath: String) -> [ProjectIssue] {
        fetchOpen(projectPath: projectPath, limit: nil)
    }

    /// 获取指定项目未解决的问题，按严重程度排序，可限制数量。
    ///
    /// 排序规则：critical → warning → info，同级别按更新时间倒序。
    /// - Parameters:
    ///   - projectPath: 项目根路径
    ///   - limit: 最大返回数量，nil 表示不限
    public func fetchOpen(projectPath: String, limit: Int?) -> [ProjectIssue] {
        let normalizedPath = normalizeProjectPath(projectPath)
        let filtered = issues.filter { issue in
            issue.isOpen && (issue.projectPath.isEmpty || normalizeProjectPath(issue.projectPath) == normalizedPath)
        }

        let sorted = filtered.sorted { lhs, rhs in
            let leftOrder = severityOrder(lhs.severity)
            let rightOrder = severityOrder(rhs.severity)
            if leftOrder != rightOrder { return leftOrder < rightOrder }
            return lhs.updatedAt > rhs.updatedAt
        }

        if let limit {
            let normalizedLimit = max(0, limit)
            guard normalizedLimit > 0 else { return [] }
            return Array(sorted.prefix(normalizedLimit))
        }
        return sorted
    }

    /// 严重程度排序权重（值越小越靠前）
    private func severityOrder(_ severity: ProjectIssueSeverity) -> Int {
        switch severity {
        case .critical: return 0
        case .warning:  return 1
        case .info:     return 2
        }
    }

    /// 获取所有问题
    public func fetchAll() -> [ProjectIssue] {
        issues
    }

    /// 按文件路径筛选未解决的问题
    public func fetchOpen(forFilePath path: String) -> [ProjectIssue] {
        issues.filter { $0.isOpen && $0.filePath == path }
    }

    /// 按严重程度筛选未解决的问题
    public func fetchOpen(severity: ProjectIssueSeverity) -> [ProjectIssue] {
        issues.filter { $0.isOpen && $0.severity == severity }
    }

    /// 更新问题状态
    public func updateStatus(id: UUID, status: ProjectIssueStatus) throws {
        guard let index = issues.firstIndex(where: { $0.id == id }) else { return }
        issues[index].status = status
        issues[index].updatedAt = Date()
        try persist()
    }

    /// 移除指定文件的所有问题（文件已删除或重命名时使用）
    public func removeIssues(forFilePath path: String) throws {
        issues.removeAll { $0.filePath == path }
        try persist()
    }

    /// 替换某个项目下指定来源的问题，保留用户已确认/忽略的问题状态。
    public func replaceIssues(projectPath: String, source: ProjectIssueSource, with newIssues: [ProjectIssue]) throws {
        let normalizedPath = normalizeProjectPath(projectPath)
        let previousByKey = Self.groupByDedupeKey(issues)
        let incomingKeys = Set(newIssues.map(\.dedupeKey))

        issues.removeAll { issue in
            normalizeProjectPath(issue.projectPath) == normalizedPath
                && issue.source == source
                && issue.isOpen
                && !incomingKeys.contains(issue.dedupeKey)
        }

        for issue in newIssues {
            var nextIssue = issue
            if let previous = previousByKey[issue.dedupeKey] {
                nextIssue.status = previous.status
                nextIssue.updatedAt = Date()
            }

            if let index = issues.firstIndex(where: { $0.dedupeKey == nextIssue.dedupeKey }) {
                issues[index] = nextIssue
            } else {
                issues.append(nextIssue)
            }
        }

        try persist()
    }

    /// 清空所有问题
    public func clearAll() throws {
        issues.removeAll()
        try persist()
    }

    /// 未解决问题的数量
    public func openCount() -> Int {
        issues.filter(\.isOpen).count
    }

    // MARK: - Private

    static func loadFromDisk(from url: URL) throws -> [ProjectIssue] {
        let data = try Data(contentsOf: url)
        let decodedIssues = try makeDecoder().decode([ProjectIssue].self, from: data)
        return deduplicated(decodedIssues)
    }

    private func persist() throws {
        issues = Self.deduplicated(issues)
        let data = try Self.makeEncoder().encode(issues)
        try data.write(to: issuesFileURL, options: [.atomic])
    }

    private static func groupByDedupeKey(_ issues: [ProjectIssue]) -> [String: ProjectIssue] {
        var grouped: [String: ProjectIssue] = [:]
        for issue in issues where grouped[issue.dedupeKey] == nil {
            grouped[issue.dedupeKey] = issue
        }
        return grouped
    }

    private static func deduplicated(_ issues: [ProjectIssue]) -> [ProjectIssue] {
        var seenKeys = Set<String>()
        return issues.filter { issue in
            seenKeys.insert(issue.dedupeKey).inserted
        }
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func normalizeProjectPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
