import Foundation

/// LumiCore 的"存储"功能组件。
///
/// 负责管理数据根目录，提供核心数据目录和插件专属数据目录的路径计算。
/// 目录会在首次访问时自动创建。
@MainActor
public final class StorageComponent {
    /// 数据根目录。init 时物化,始终不变。
    public let dataRootDirectory: URL

    public init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory
    }

    /// 核心数据目录(`<dataRootDirectory>/Core`,自动创建)。
    public var coreDataDirectory: URL {
        Self._directory(named: "Core", under: dataRootDirectory)
    }

    /// 插件专属数据目录(`<dataRootDirectory>/<PluginName>`,自动创建)。
    /// - Parameter pluginName: 插件名称(会被 sanitize:非字母数字字符替换为 `_`)。
    /// - Returns: 插件专属的数据目录路径。
    public func pluginDataDirectory(for pluginName: String) -> URL {
        Self._directory(
            named: Self._sanitizeDirectoryName(pluginName, fallback: "Plugin"),
            under: dataRootDirectory
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

    /// 清理目录名称,移除非法字符(字母数字保留,其余转 `_`)。
    private static func _sanitizeDirectoryName(_ name: String, fallback: String) -> String {
        let sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")

        return sanitized.isEmpty ? fallback : sanitized
    }
}
