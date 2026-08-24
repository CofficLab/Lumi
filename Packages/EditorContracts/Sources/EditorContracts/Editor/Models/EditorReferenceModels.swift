import Foundation

// MARK: - 引用结果模型（契约 V2）

/// 单条引用/定义/实现结果位置。
///
/// `line`/`column` 与宿主实现语义一致（供 UI 展示）；
/// 打开位置使用 `EditorLocation`（zero-based UTF-16）。
public struct EditorReferenceItem: Identifiable, Equatable, Sendable {
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
        "\(uri.standardizedFileURL.path)#\(line):\(column):\(preview)"
    }

    /// 通过导航打开该位置时的目标。
    public var location: EditorLocation {
        EditorLocation(
            uri: uri,
            range: EditorRange(at: EditorPosition(line: max(0, line - 1), character: max(0, column - 1)))
        )
    }
}

/// 引用面板状态快照。
public struct EditorReferencesState: Equatable, Sendable {
    public let results: [EditorReferenceItem]
    public let selected: EditorReferenceItem?

    public init(results: [EditorReferenceItem], selected: EditorReferenceItem?) {
        self.results = results
        self.selected = selected
    }

    public static let empty = EditorReferencesState(results: [], selected: nil)
}
