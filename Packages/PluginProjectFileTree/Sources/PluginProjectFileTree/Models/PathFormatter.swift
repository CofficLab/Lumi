import Foundation

public enum PathFormatter {
    public static func expansionPath(for nodeURL: URL, projectRootPath: String) -> String {
        relativePath(
            for: nodeURL,
            projectRootPath: projectRootPath,
            includeLeadingSlash: true,
            outsideProjectFallback: normalizedPath(nodeURL.path)
        )
    }

    public static func gitPath(for nodeURL: URL, projectRootPath: String) -> String {
        relativePath(
            for: nodeURL,
            projectRootPath: projectRootPath,
            includeLeadingSlash: false,
            outsideProjectFallback: ""
        )
    }

    private static func relativePath(
        for nodeURL: URL,
        projectRootPath: String,
        includeLeadingSlash: Bool,
        outsideProjectFallback: String
    ) -> String {
        guard !projectRootPath.isEmpty else { return "" }

        let rootPath = normalizedPath(projectRootPath)
        let nodePath = normalizedPath(nodeURL.path)

        guard nodePath != rootPath else { return "" }

        let rootPrefix = rootPath == "/" ? "/" : rootPath + "/"
        guard nodePath.hasPrefix(rootPrefix) else { return outsideProjectFallback }

        let relative = String(nodePath.dropFirst(rootPrefix.count))
        return includeLeadingSlash ? "/" + relative : relative
    }

    static func normalizedFilePath(_ url: URL) -> String {
        normalizedPath(url.path)
    }

    static func isSameFile(_ lhs: URL?, _ rhs: URL) -> Bool {
        guard let lhs else { return false }
        return normalizedFilePath(lhs) == normalizedFilePath(rhs)
    }

    /// 批量操作时去掉被其它选中目录包含的子路径。
    ///
    /// 排序后线性扫描：字典序保证子路径紧跟父路径，只需与上一个顶层路径比较。
    static func topLevelURLs(from urls: [URL]) -> [URL] {
        let pairs = urls.map { (url: $0, path: normalizedFilePath($0)) }
        let sortedPaths = pairs.map(\.path).sorted()
        var topPaths = Set<String>()
        var lastTopLevel: String?
        for path in sortedPaths {
            if let last = lastTopLevel, path.hasPrefix(last + "/") {
                continue
            }
            topPaths.insert(path)
            lastTopLevel = path
        }
        return pairs.filter { topPaths.contains($0.path) }.map(\.url)
    }

    private static func normalizedPath(_ path: String) -> String {
        let standardized = (path as NSString).standardizingPath
        guard standardized.count > 1 else { return standardized }
        return standardized.hasSuffix("/") ? String(standardized.dropLast()) : standardized
    }
}