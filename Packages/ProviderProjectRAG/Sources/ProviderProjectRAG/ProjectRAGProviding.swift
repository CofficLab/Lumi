import Foundation

@MainActor
public enum ProjectRAGEvent: Sendable, Equatable {
    case initialized
    case projectChanged(String?)
    case indexingStarted(String)
    case indexingFinished(String)
}

@MainActor
public protocol ProjectRAGObserverHandle: AnyObject {
    func cancel()
}

/// Project RAG 的中立检索能力。
///
/// 内核和其他插件只依赖这个协议；索引实现、数据库和 embedding provider
/// 由具体插件负责。
@MainActor
public protocol ProjectRAGProviding: AnyObject, Sendable {
    var isInitialized: Bool { get }
    var currentProjectPath: String? { get }

    /// 判断指定项目是否正在索引，供首次查询避免重复启动前台索引。
    func isIndexing(projectPath: String) -> Bool

    @discardableResult
    func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle

    func search(
        query: String,
        projectPath: String?,
        topK: Int
    ) async throws -> ProjectRAGResponse

    func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws

    func indexStatus(projectPath: String) async throws -> ProjectRAGIndexStatus?
}

public extension ProjectRAGProviding {
    func isIndexing(projectPath: String) -> Bool { false }

    @discardableResult
    func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle {
        NoopProjectRAGObserverHandle()
    }
}

@MainActor
public final class NoopProjectRAGObserverHandle: ProjectRAGObserverHandle {
    public init() {}
    public func cancel() {}
}

public extension ProjectRAGProviding {
    func search(query: String, projectPath: String? = nil, topK: Int = 8) async throws -> ProjectRAGResponse {
        try await search(query: query, projectPath: projectPath, topK: topK)
    }

    func ensureIndexed(projectPath: String) async throws {
        try await ensureIndexed(projectPath: projectPath, force: false, background: false)
    }
}

public enum ProjectRAGMatchKind: String, Sendable, Equatable {
    case semantic
    case indexedLexical
    case filesystemLexical
}

public struct ProjectRAGSearchResult: Sendable, Equatable {
    public let content: String
    public let source: String
    public let score: Float
    public let matchKind: ProjectRAGMatchKind

    public init(
        content: String,
        source: String,
        score: Float,
        matchKind: ProjectRAGMatchKind
    ) {
        self.content = content
        self.source = source
        self.score = score
        self.matchKind = matchKind
    }

    public init(content: String, source: String, score: Float) {
        self.init(content: content, source: source, score: score, matchKind: .semantic)
    }
}

public struct ProjectRAGResponse: Sendable, Equatable {
    public let query: String
    public let results: [ProjectRAGSearchResult]

    public init(query: String, results: [ProjectRAGSearchResult]) {
        self.query = query
        self.results = results
    }
}

public struct ProjectRAGIndexStatus: Sendable, Equatable {
    public let projectPath: String
    public let lastIndexedAt: Date
    public let fileCount: Int
    public let chunkCount: Int
    public let isStale: Bool

    public init(
        projectPath: String,
        lastIndexedAt: Date,
        fileCount: Int,
        chunkCount: Int,
        isStale: Bool
    ) {
        self.projectPath = projectPath
        self.lastIndexedAt = lastIndexedAt
        self.fileCount = fileCount
        self.chunkCount = chunkCount
        self.isStale = isStale
    }
}
