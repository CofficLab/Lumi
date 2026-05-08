import Foundation

/// 文件搜索结果模型（Quick Open / 索引共用）
public struct FileResult: Identifiable, Equatable, Hashable {
    public let id: UUID
    public let name: String
    public let path: String
    public let relativePath: String
    public let isDirectory: Bool
    public let score: Int

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        relativePath: String,
        isDirectory: Bool,
        score: Int
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.relativePath = relativePath
        self.isDirectory = isDirectory
        self.score = score
    }

    public var url: URL {
        URL(fileURLWithPath: path)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: FileResult, rhs: FileResult) -> Bool {
        lhs.id == rhs.id
    }
}

/// 文件索引模型
public struct FileIndex {
    public let projectPath: String
    public let files: [FileResult]
    public let lastUpdated: Date

    public init(projectPath: String, files: [FileResult], lastUpdated: Date) {
        self.projectPath = projectPath
        self.files = files
        self.lastUpdated = lastUpdated
    }

    /// 检查索引是否过期（超过 5 分钟）
    public var isExpired: Bool {
        Date().timeIntervalSince(lastUpdated) > 300
    }
}
