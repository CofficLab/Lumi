import Foundation

enum XcodeProjectPathUtility {
    static func relativePath(for path: String, rootPath: String, fallbackName: String? = nil) -> String {
        let filePath = normalizedPath(path)
        let root = normalizedPath(rootPath)

        guard !root.isEmpty, filePath != root else {
            return fallbackName ?? (filePath as NSString).lastPathComponent
        }

        let rootPrefix = root == "/" ? "/" : root + "/"
        guard filePath.hasPrefix(rootPrefix) else {
            return fallbackName ?? (filePath as NSString).lastPathComponent
        }

        return String(filePath.dropFirst(rootPrefix.count))
    }

    private static func normalizedPath(_ path: String) -> String {
        let standardized = (path as NSString).standardizingPath
        guard standardized.count > 1 else { return standardized }
        return standardized.hasSuffix("/") ? String(standardized.dropLast()) : standardized
    }
}
