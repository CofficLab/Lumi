import Foundation

enum RAGFileScanner {
    /// 需要跳过的目录列表
    static let skipDirectories: Set<String> = [
        ".git", ".build", ".swiftpm", "DerivedData", "Pods", "Carthage", "node_modules", "dist", "build",
    ]

    /// 允许索引的文件扩展名
    static let allowedExtensions: Set<String> = [
        "swift", "m", "mm", "h", "hpp", "c", "cc", "cpp",
        "js", "ts", "tsx", "jsx", "json", "yml", "yaml", "toml",
        "md", "txt", "rst", "py", "rb", "go", "rs", "java", "kt",
        "sql", "html", "css", "scss", "xml", "sh", "zsh",
    ]

    /// 默认最大文件大小限制（1.5MB）
    static let defaultMaxFileSizeBytes = 1_500_000

    /// 扫描项目目录下的所有文件
    /// - Parameters:
    ///   - projectPath: 项目根目录路径
    ///   - maxFileSizeBytes: 文件大小限制（字节）
    /// - Returns: 文件路径数组
    static func discoverFiles(in projectPath: String, maxFileSizeBytes: Int = defaultMaxFileSizeBytes) -> [String] {
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
    static func shouldSkipPath(_ path: String) -> Bool {
        let components = path.split(separator: "/").map(String.init)
        for component in components where Self.skipDirectories.contains(component) {
            return true
        }
        return false
    }
}
