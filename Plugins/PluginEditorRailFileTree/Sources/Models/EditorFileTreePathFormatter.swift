import Foundation

enum EditorFileTreePathFormatter {
    static func expansionPath(for nodeURL: URL, projectRootPath: String) -> String {
        relativePath(
            for: nodeURL,
            projectRootPath: projectRootPath,
            includeLeadingSlash: true,
            outsideProjectFallback: normalizedPath(nodeURL.path)
        )
    }

    static func gitPath(for nodeURL: URL, projectRootPath: String) -> String {
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

    private static func normalizedPath(_ path: String) -> String {
        let standardized = (path as NSString).standardizingPath
        guard standardized.count > 1 else { return standardized }
        return standardized.hasSuffix("/") ? String(standardized.dropLast()) : standardized
    }
}
