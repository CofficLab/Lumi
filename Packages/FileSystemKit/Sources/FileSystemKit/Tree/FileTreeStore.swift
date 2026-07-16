import Foundation
import os
import SuperLogKit

/// 文件树状态持久化存储
///
/// 负责持久化文件树的展开状态和最近项目路径。
/// 通过 Property List 文件进行读写，使用串行队列保证线程安全。
///
/// 性能优化：
/// - 展开状态变更采用内存缓存 + 防抖落盘策略
/// - 频繁的 add/remove 操作只更新内存，通过 debounce 批量写入磁盘
///
/// 使用方式：
/// ```swift
/// let store = FileTreeStore(directory: storeDirectory)
/// store.setExpandedPaths(["/src", "/lib"], for: "/path/to/project")
/// let paths = store.expandedPaths(for: "/path/to/project")
/// ```
public final class FileTreeStore: SuperLog, @unchecked Sendable {

    // MARK: - Properties

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "file-tree-store")
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "FileTreeStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL
    private let corruptSettingsFileURL: URL

    // MARK: - Debounce Properties

    /// 内存缓存：按项目路径存储展开状态
    private var expandedPathsCache: [String: Set<String>] = [:]
    
    /// 待落盘的脏数据标记
    private var hasDirtyCache = false
    
    /// 防抖任务
    private var persistTask: DispatchWorkItem?
    
    /// 防抖间隔（秒）
    private let persistDebounceInterval: TimeInterval = 1.0

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
        self.corruptSettingsFileURL = directory.appendingPathComponent("settings.corrupt.plist")
        do {
            try fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(Self.t)Create file tree settings directory failed: \(error.localizedDescription)")
        }
    }

    deinit {
        persistTask?.cancel()
    }

    // MARK: - Public API

    /// 存储值
    @discardableResult
    public func set(_ value: Any?, forKey key: String) -> Bool {
        queue.sync {
            guard let dict = readDict() else {
                return false
            }

            var nextDict = dict
            if let value {
                nextDict[key] = value
            } else {
                nextDict.removeValue(forKey: key)
            }
            return writeDict(nextDict)
        }
    }

    /// 获取值
    public func object(forKey key: String) -> Any? {
        queue.sync { readDict()?[key] }
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
        // 优先从内存缓存读取
        if let cached = expandedPathsCache[projectRoot] {
            return cached
        }
        
        // 缓存未命中，从磁盘加载
        let key = expandedPathsKey(for: projectRoot)
        guard let paths = object(forKey: key) as? [String] else { return [] }
        let pathSet = Set(paths)
        expandedPathsCache[projectRoot] = pathSet
        return pathSet
    }

    /// 保存已展开的文件夹相对路径集合（立即落盘）
    ///
    /// - Parameters:
    ///   - paths: 相对路径集合
    ///   - projectRoot: 项目根目录的绝对路径
    @discardableResult
    public func setExpandedPaths(_ paths: Set<String>, for projectRoot: String) -> Bool {
        expandedPathsCache[projectRoot] = paths
        let key = expandedPathsKey(for: projectRoot)
        return set(Array(paths), forKey: key)
    }

    /// 添加一个展开的文件夹路径（内存缓存 + 防抖落盘）
    @discardableResult
    public func addExpandedPath(_ relativePath: String, for projectRoot: String) -> Bool {
        var paths = expandedPaths(for: projectRoot)
        paths.insert(relativePath)
        expandedPathsCache[projectRoot] = paths
        schedulePersist(for: projectRoot)
        return true
    }

    /// 移除一个折叠的文件夹路径（内存缓存 + 防抖落盘）
    @discardableResult
    public func removeExpandedPath(_ relativePath: String, for projectRoot: String) -> Bool {
        var paths = expandedPaths(for: projectRoot)
        paths.remove(relativePath)
        expandedPathsCache[projectRoot] = paths
        schedulePersist(for: projectRoot)
        return true
    }

    /// 立即将所有脏缓存落盘（用于应用退出等场景）
    public func flushDirtyCache() {
        queue.sync {
            guard hasDirtyCache else { return }
            persistDirtyCacheSync()
        }
    }

    /// 记录上次打开的项目路径
    @discardableResult
    public func setLastProjectPath(_ path: String) -> Bool {
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

    /// 调度防抖落盘任务
    private func schedulePersist(for projectRoot: String) {
        hasDirtyCache = true
        
        // 取消之前的任务
        persistTask?.cancel()
        
        // 创建新的防抖任务
        let workItem = DispatchWorkItem { [weak self] in
            self?.persistDirtyCache()
        }
        persistTask = workItem
        
        queue.asyncAfter(deadline: .now() + persistDebounceInterval, execute: workItem)
    }

    /// 执行落盘（异步队列中）
    private func persistDirtyCache() {
        queue.async { [weak self] in
            self?.persistDirtyCacheSync()
        }
    }

    /// 同步落盘所有脏缓存（必须在 queue 中调用）
    private func persistDirtyCacheSync() {
        guard hasDirtyCache else { return }
        
        // 加载现有磁盘数据
        var dict = readDict() ?? [:]
        
        // 将内存缓存写入字典
        for (projectRoot, paths) in expandedPathsCache {
            let key = expandedPathsKey(for: projectRoot)
            dict[key] = Array(paths)
        }
        
        // 写入磁盘
        if writeDict(dict) {
            hasDirtyCache = false
        }
    }

    /// 从文件读取字典
    private func readDict() -> [String: Any]? {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("\(Self.t)Read file tree settings failed: root plist is not a dictionary")
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            Self.logger.error("\(Self.t)Read file tree settings failed: \(error.localizedDescription)")
            quarantineCorruptSettings()
            return [:]
        }
    }

    /// 写入字典到文件（原子操作）
    @discardableResult
    private func writeDict(_ dict: [String: Any]) -> Bool {
        let data: Data
        do {
            data = try PropertyListSerialization.data(
                fromPropertyList: dict,
                format: .binary,
                options: 0
            )
        } catch {
            Self.logger.error("\(Self.t)Encode file tree settings failed: \(error.localizedDescription)")
            return false
        }

        let tmpURL = pluginDirectory.appendingPathComponent("settings.tmp")

        do {
            try fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
            try data.write(to: tmpURL, options: .atomic)
            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try fileManager.replaceItemAt(settingsFileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: settingsFileURL)
            }
            return true
        } catch {
            Self.logger.error("\(Self.t)Persist file tree settings failed: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tmpURL)
            return false
        }
    }

    private func quarantineCorruptSettings() {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return }

        do {
            if fileManager.fileExists(atPath: corruptSettingsFileURL.path) {
                try fileManager.removeItem(at: corruptSettingsFileURL)
            }
            try fileManager.moveItem(at: settingsFileURL, to: corruptSettingsFileURL)
        } catch {
            Self.logger.error("\(Self.t)Quarantine corrupt file tree settings failed: \(error.localizedDescription)")
        }
    }
}
