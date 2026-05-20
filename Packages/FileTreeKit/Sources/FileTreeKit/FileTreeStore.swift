import Foundation

/// 文件树状态持久化存储
///
/// 负责持久化文件树的展开状态和最近项目路径。
/// 通过 Property List 文件进行读写，使用串行队列保证线程安全。
///
/// 使用方式：
/// ```swift
/// let store = FileTreeStore(directory: storeDirectory)
/// store.setExpandedPaths(["/src", "/lib"], for: "/path/to/project")
/// let paths = store.expandedPaths(for: "/path/to/project")
/// ```
public final class FileTreeStore: @unchecked Sendable {

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "FileTreeStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL

    // MARK: - Keys

    private enum Keys {
        static let expandedPaths = "expanded_paths"
        static let lastProjectPath = "last_project_path"
    }

    // MARK: - Initialization

    /// 初始化存储
    /// - Parameter directory: 存储目录 URL，会在其中创建 `settings.plist` 文件
    public init(directory: URL) {
        self.pluginDirectory = directory
        self.settingsFileURL = directory.appendingPathComponent("settings.plist")
        try? fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// 存储值
    public func set(_ value: Any?, forKey key: String) {
        queue.sync {
            var dict = readDict()
            if let value {
                dict[key] = value
            } else {
                dict.removeValue(forKey: key)
            }
            writeDict(dict)
        }
    }

    /// 获取值
    public func object(forKey key: String) -> Any? {
        queue.sync { readDict()[key] }
    }

    /// 获取字符串
    public func string(forKey key: String) -> String? {
        object(forKey: key) as? String
    }

    // MARK: - Expanded Paths

    /// 获取已展开的文件夹相对路径集合
    ///
    /// - Parameter projectRoot: 项目根目录的绝对路径
    /// - Returns: 相对路径集合
    public func expandedPaths(for projectRoot: String) -> Set<String> {
        let key = expandedPathsKey(for: projectRoot)
        guard let paths = object(forKey: key) as? [String] else { return [] }
        return Set(paths)
    }

    /// 保存已展开的文件夹相对路径集合
    ///
    /// - Parameters:
    ///   - paths: 相对路径集合
    ///   - projectRoot: 项目根目录的绝对路径
    public func setExpandedPaths(_ paths: Set<String>, for projectRoot: String) {
        let key = expandedPathsKey(for: projectRoot)
        set(Array(paths), forKey: key)
    }

    /// 添加一个展开的文件夹路径
    public func addExpandedPath(_ relativePath: String, for projectRoot: String) {
        var paths = expandedPaths(for: projectRoot)
        paths.insert(relativePath)
        setExpandedPaths(paths, for: projectRoot)
    }

    /// 移除一个折叠的文件夹路径
    public func removeExpandedPath(_ relativePath: String, for projectRoot: String) {
        var paths = expandedPaths(for: projectRoot)
        paths.remove(relativePath)
        setExpandedPaths(paths, for: projectRoot)
    }

    /// 记录上次打开的项目路径
    public func setLastProjectPath(_ path: String) {
        set(path, forKey: Keys.lastProjectPath)
    }

    /// 获取上次打开的项目路径
    public func lastProjectPath() -> String? {
        string(forKey: Keys.lastProjectPath)
    }

    // MARK: - Private Helpers

    /// 按项目路径生成展开状态的存储 key
    private func expandedPathsKey(for projectRoot: String) -> String {
        "\(Keys.expandedPaths).\(sanitize(projectRoot))"
    }

    /// 将路径转为安全的 key 字符串
    /// 使用 URL 编码确保不同路径不会碰撞
    private func sanitize(_ key: String) -> String {
        key.data(using: .utf8).map { data in
            data.map { byte in
                String(format: "%02x", byte)
            }.joined()
        } ?? key
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
