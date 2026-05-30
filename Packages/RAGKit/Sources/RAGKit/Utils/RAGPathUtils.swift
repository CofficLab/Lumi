import Foundation

public enum RAGPathUtils {
    /// 标准化项目路径
    public static func normalizeProjectPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let normalized = URL(fileURLWithPath: trimmed).standardizedFileURL.path
        return normalized != "/" && normalized.hasSuffix("/") ? String(normalized.dropLast()) : normalized
    }

    /// 格式化显示路径，相对于项目路径显示更友好的形式
    public static func displayPath(filePath: String, projectPath: String?) -> String {
        let normalizedFilePath = normalizeProjectPath(filePath)
        guard let projectPath else { return normalizedFilePath }

        let normalizedProjectPath = normalizeProjectPath(projectPath)
        guard !normalizedProjectPath.isEmpty else { return normalizedFilePath }

        if normalizedFilePath == normalizedProjectPath {
            return URL(fileURLWithPath: normalizedFilePath).lastPathComponent
        }

        let projectPrefix = normalizedProjectPath == "/" ? "/" : normalizedProjectPath + "/"
        if normalizedFilePath.hasPrefix(projectPrefix) {
            let index = normalizedFilePath.index(normalizedFilePath.startIndex, offsetBy: projectPrefix.count)
            let suffix = String(normalizedFilePath[index...])
            return suffix.hasPrefix("/") ? String(suffix.dropFirst()) : suffix
        }
        return normalizedFilePath
    }
}
