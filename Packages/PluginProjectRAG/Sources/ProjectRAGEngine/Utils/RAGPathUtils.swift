import Foundation

public enum RAGPathUtils {
    /// 标准化项目路径。
    ///
    /// 空白串视为无效返回空串；除此之外不做空白 trim——macOS 目录名可以
    /// 合法地以空格开头/结尾，trim 会把显式路径改写成另一个真实存在的
    /// 目录（issue #605）。
    public static func normalizeProjectPath(_ path: String) -> String {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
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
