import Foundation
import ProviderStorage

/// 根落在临时目录的 `StorageProviding`，目录形状与生产一致。
///
/// ## 为什么不是 `isStoredInMemoryOnly`
///
/// 内存存储（SwiftData `isStoredInMemoryOnly`）看似更干净，但会**丢掉真实行为**：
/// SQL 层错误、事务边界、并发写冲突、schema 迁移、路径拼接——这些恰恰是
/// Bug 高发区。全部换成内存替身，等于把这些场景从测试覆盖里抹掉。
///
/// 因此这里保留**真实 SQLite / SwiftData**，只把**根目录**换到临时位置：
/// 既隔离了开发者本机数据，又测到了真实的持久化路径。
///
/// ## 目录形状
///
/// ```text
/// <temporaryDirectory>/<prefix>-<uuid>/
///   └── db_debug_v6/          ← 与生产同名，兼容版本发现与迁移逻辑
///       ├── Core/
///       └── <pluginID>/
/// ```
///
/// 保留 `db_debug_v6` 这个名字很关键：内核的 `allVersionDataRootDirectories`
/// 与 `PluginDataMigrationRunner` 都按 `db_debug_v*` 前缀做版本解析，
/// 换成任意名字会让这些逻辑在测试里走不到真正的分支。
///
/// ## 用法
///
/// ```swift
/// let storage = try TemporaryStorageProvider.make(prefix: "chat-panel")
/// defer { storage.cleanup() }
/// try kernel.registerProvider((any StorageProviding).self, storage)
/// ```
@MainActor
public final class TemporaryStorageProvider: StorageProviding {

    /// 数据根目录，形状为 `<temp>/db_debug_v6`。
    public let dataRootDirectory: URL

    /// 创建于临时目录的根，清理时删除它即可。
    private let temporaryRoot: URL

    /// 数据根目录名。沿用生产命名，使版本发现 / 迁移逻辑在测试中同样生效。
    public static let dataRootDirectoryName = "db_debug_v6"

    private init(temporaryRoot: URL) {
        self.temporaryRoot = temporaryRoot
        self.dataRootDirectory = temporaryRoot
            .appendingPathComponent(Self.dataRootDirectoryName, isDirectory: true)
        Self.ensureDirectory(self.dataRootDirectory)
    }

    /// 创建临时根的存储 Provider。
    ///
    /// - Parameter prefix: 用途前缀，仅用于磁盘上可辨识。
    public static func make(prefix: String) throws -> TemporaryStorageProvider {
        let directory = try TemporaryDirectory.make(prefix)
        return TemporaryStorageProvider(temporaryRoot: directory.url)
    }

    /// 删除整个临时根。
    public func cleanup() {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    // MARK: - StorageProviding

    public func pluginDataDirectory(for pluginID: String) -> URL {
        let directory = dataRootDirectory.appendingPathComponent(pluginID, isDirectory: true)
        Self.ensureDirectory(directory)
        return directory
    }

    public func coreDataDirectory() -> URL {
        let directory = dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
        Self.ensureDirectory(directory)
        return directory
    }

    private static func ensureDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}