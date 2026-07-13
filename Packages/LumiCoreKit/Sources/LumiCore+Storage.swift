import Foundation

public extension LumiCore {
    // MARK: - Configuration

    /// 核心配置实例
    private static var _configuration: LumiCoreConfiguration?

    /// 配置存储根目录。
    /// - Parameter dataRootDirectory: 数据根目录路径。
    public static func configure(dataRootDirectory: URL) throws {
        let directory = dataRootDirectory.standardizedFileURL
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        _configuration = LumiCoreConfiguration(dataRootDirectory: directory)
    }

    /// 核心数据目录。
    public static var coreDataDirectory: URL {
        _directory(named: "Core", under: Self.dataRootDirectory!)
    }

    /// 插件数据目录。
    /// - Parameter pluginName: 插件名称。
    /// - Returns: 插件专属的数据目录路径。
    public static func pluginDataDirectory(for pluginName: String) -> URL {
        _directory(named: _sanitizeDirectoryName(pluginName, fallback: "Plugin"), under: dataRootDirectory!)
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
