import Foundation

/// AgentAutoApprovePlugin 插件本地存储
///
/// 负责持久化插件按项目隔离的自动批准设置。
/// 存储位置：AppConfig.getDBFolderURL()/AgentAutoApprovePlugin/settings.plist
final class AgentAutoApprovePluginLocalStore: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = AgentAutoApprovePluginLocalStore()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "AgentAutoApprovePluginLocalStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL

    // MARK: - Initialization

    private init() {
        let root = AppConfig.getDBFolderURL()
            .appendingPathComponent("AgentAutoApprovePlugin", isDirectory: true)
        self.pluginDirectory = root
        self.settingsFileURL = root.appendingPathComponent("settings.plist")
        try? fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// 加载指定项目的自动批准设置
    /// - Parameter projectPath: 项目路径
    /// - Returns: 设置值，nil 表示没有保存过
    func loadEnabled(for projectPath: String) -> Bool? {
        queue.sync {
            let dict = readDict()
            return dict[key(for: projectPath)] as? Bool
        }
    }

    /// 保存指定项目的自动批准设置
    /// - Parameters:
    ///   - enabled: 是否启用
    ///   - projectPath: 项目路径
    func saveEnabled(_ enabled: Bool, for projectPath: String) {
        queue.sync {
            var dict = readDict()
            dict[key(for: projectPath)] = enabled
            writeDict(dict)
        }
    }

    // MARK: - Private Helpers

    private func key(for projectPath: String) -> String {
        // 使用项目路径的 base64 编码作为 key，避免路径中的特殊字符问题
        return projectPath.data(using: .utf8)?
            .base64EncodedString() ?? projectPath
    }

    /// 从文件读取字典
    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path),
              let data = try? Data(contentsOf: settingsFileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return [:]
        }
        return dict
    }

    /// 写入字典到文件（原子操作）
    private func writeDict(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        ) else { return }

        let tmpURL = pluginDirectory.appendingPathComponent("settings.tmp")

        do {
            try data.write(to: tmpURL, options: .atomic)

            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try? fileManager.replaceItemAt(settingsFileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: settingsFileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tmpURL)
        }
    }
}
