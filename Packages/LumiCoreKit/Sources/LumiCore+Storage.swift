import Foundation

// MARK: - Storage Helpers

extension LumiCore {
    /// 核心数据目录。
    public var coreDataDirectory: URL {
        Self._directory(named: "Core", under: dataRootDirectory!)
    }

    /// 插件数据目录。
    /// - Parameter pluginName: 插件名称。
    /// - Returns: 插件专属的数据目录路径。
    public func pluginDataDirectory(for pluginName: String) -> URL {
        Self._directory(
            named: Self._sanitizeDirectoryName(pluginName, fallback: "Plugin"),
            under: dataRootDirectory!
        )
    }

    // MARK: - Private Helpers

    /// 创建子目录并返回路径。
    private static func _directory(named name: String, under root: URL) -> URL {
        let directory = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return directory
    }

    /// 清理目录名称，移除非法字符。
    private static func _sanitizeDirectoryName(_ name: String, fallback: String) -> String {
        let sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")

        return sanitized.isEmpty ? fallback : sanitized
    }
}