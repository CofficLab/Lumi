import Foundation

enum ProjectIssuePathFormatter {
    static func relativePath(for fileURL: URL, rootURL: URL) -> String {
        let rootPath = rootURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path

        guard filePath == rootPath || filePath.hasPrefix(directoryPrefix(for: rootPath)) else {
            return filePath
        }

        return String(filePath.dropFirst(rootPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func relativePath(for fileURL: URL, projectPath: String) -> String {
        relativePath(for: fileURL, rootURL: URL(fileURLWithPath: projectPath))
    }

    private static func directoryPrefix(for path: String) -> String {
        path == "/" ? "/" : path + "/"
    }
}
