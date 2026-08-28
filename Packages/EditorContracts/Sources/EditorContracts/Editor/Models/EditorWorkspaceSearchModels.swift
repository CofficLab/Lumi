import Foundation

// MARK: - 工作区搜索模型（契约 V2）

/// 单条搜索命中。
public struct EditorSearchMatch: Identifiable, Equatable, Sendable {
    public let uri: URL

    /// 展示用行号（与宿主语义一致）。
    public let line: Int

    /// 展示用列号（与宿主语义一致）。
    public let column: Int

    /// 相对工作区路径（展示用）。
    public let path: String

    /// 命中行预览文本。
    public let preview: String

    public init(uri: URL, line: Int, column: Int, path: String, preview: String) {
        self.uri = uri
        self.line = line
        self.column = column
        self.path = path
        self.preview = preview
    }

    public var id: String {
        "\(path):\(line):\(column):\(preview)"
    }

    /// 通过导航打开该命中时的目标。
    public var location: EditorLocation {
        EditorLocation(
            uri: uri,
            range: EditorRange(at: EditorPosition(line: max(0, line - 1), character: max(0, column - 1)))
        )
    }
}

/// 按文件分组的搜索结果。
public struct EditorSearchFileResult: Identifiable, Equatable, Sendable {
    public let uri: URL
    public let path: String
    public let matches: [EditorSearchMatch]

    public var id: String { path }
    public var matchCount: Int { matches.count }

    public init(uri: URL, path: String, matches: [EditorSearchMatch]) {
        self.uri = uri
        self.path = path
        self.matches = matches
    }
}

/// 搜索汇总。
public struct EditorSearchSummary: Equatable, Sendable {
    public let query: String
    public let totalMatches: Int
    public let totalFiles: Int

    public init(query: String, totalMatches: Int, totalFiles: Int) {
        self.query = query
        self.totalMatches = totalMatches
        self.totalFiles = totalFiles
    }
}

/// 工作区搜索面板状态快照（UI 折叠等局部状态由插件自持）。
public struct EditorWorkspaceSearchState: Equatable, Sendable {
    public let results: [EditorSearchFileResult]
    public let summary: EditorSearchSummary?
    public let errorMessage: String?
    public let isLoading: Bool

    public init(
        results: [EditorSearchFileResult],
        summary: EditorSearchSummary?,
        errorMessage: String?,
        isLoading: Bool
    ) {
        self.results = results
        self.summary = summary
        self.errorMessage = errorMessage
        self.isLoading = isLoading
    }

    public static let empty = EditorWorkspaceSearchState(results: [], summary: nil, errorMessage: nil, isLoading: false)
}
