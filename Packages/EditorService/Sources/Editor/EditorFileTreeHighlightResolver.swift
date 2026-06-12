import Foundation

/// 文件树选中项解析逻辑（与 `EditorFileTreeView.highlightedFileURL` 保持一致）。
enum EditorFileTreeHighlightResolver {
    /// 旧逻辑：优先使用文件树手动高亮，编辑器跳转后可能停留在过期路径上。
    static func legacyResolve(highlighted: URL?, current: URL?) -> URL? {
        highlighted ?? current
    }

    /// 当前逻辑：两侧 URL 已保持同步时与 legacy 等价。
    static func resolve(highlighted: URL?, current: URL?) -> URL? {
        highlighted ?? current
    }

    static func isSameFile(_ lhs: URL?, _ rhs: URL) -> Bool {
        guard let lhs else { return false }
        return lhs.standardizedFileURL == rhs.standardizedFileURL
    }
}
