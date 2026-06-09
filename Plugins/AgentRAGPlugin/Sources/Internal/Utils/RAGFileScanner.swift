import Foundation

public enum RAGFileScanner {
    /// 需要跳过的目录列表
    public static let skipDirectories: Set<String> = [
        ".git", ".build", ".swiftpm", "DerivedData", "Pods", "Carthage", "node_modules", "dist", "build",
    ]

    /// 允许索引的文件扩展名
    public static let allowedExtensions: Set<String> = [
        "swift", "m", "mm", "h", "hpp", "c", "cc", "cpp",
        "js", "ts", "tsx", "jsx", "json", "yml", "yaml", "toml",
        "md", "txt", "rst", "py", "rb", "go", "rs", "java", "kt",
        "sql", "html", "css", "scss", "xml", "sh", "zsh",
    ]

    /// 默认最大文件大小限制（1.5MB）
    public static let defaultMaxFileSizeBytes = 1_500_000

    /// 扫描项目目录下的所有文件
    public static func discoverFiles(in projectPath: String, maxFileSizeBytes: Int = defaultMaxFileSizeBytes) -> [String] {
        let rootURL = URL(fileURLWithPath: projectPath)
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [String] = []

        for case let url as URL in enumerator {
            let path = url.path
            if shouldSkipPath(path) {
                enumerator.skipDescendants()
                continue
            }

            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else {
                continue
            }

            let ext = url.pathExtension.lowercased()
            guard Self.allowedExtensions.contains(ext) else { continue }

            if let size = values.fileSize, size > maxFileSizeBytes { continue }

            files.append(path)
        }

        return files
    }

    /// 判断路径是否应该跳过
    public static func shouldSkipPath(_ path: String) -> Bool {
        let components = path.split(separator: "/").map(String.init)
        for component in components where Self.skipDirectories.contains(component) {
            return true
        }
        return false
    }
}
