import Foundation

enum RAGPathUtils {
    /// 标准化项目路径
    static func normalizeProjectPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    /// 格式化显示路径，相对于项目路径显示更友好的形式
    static func displayPath(filePath: String, projectPath: String?) -> String {
        guard let projectPath, !projectPath.isEmpty else { return filePath }
        if filePath.hasPrefix(projectPath) {
            let index = filePath.index(filePath.startIndex, offsetBy: projectPath.count)
            let suffix = String(filePath[index...])
            return suffix.hasPrefix("/") ? String(suffix.dropFirst()) : suffix
        }
        return filePath
    }
}
