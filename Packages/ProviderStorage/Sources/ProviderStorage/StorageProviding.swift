import Foundation
import KernelCore

// MARK: - Storage Capability Protocol

/// 存储能力协议 - 核心存储接口
///
/// 定义内核需要的存储功能，由具体实现包提供。
/// 是所有插件往磁盘存储数据的基础：插件通过
/// `pluginDataDirectory(for:)` 获取自己的数据目录。
@MainActor
public protocol StorageProviding: AnyObject {
    /// 数据根目录
    var dataRootDirectory: URL { get }

    /// 插件数据目录
    func pluginDataDirectory(for pluginID: String) -> URL

    /// 当前 Lumi 数据空间下所有可识别的版本根目录，包括当前目录。
    var allVersionDataRootDirectories: [URL] { get }

    /// 核心数据目录
    func coreDataDirectory() -> URL

    /// 异步计算数据根目录实际占用的磁盘空间（字节）。
    func dataRootDirectorySizeInBytes() async -> Int64
}

public extension StorageProviding {
    /// 发现当前 bundle 数据空间中的全部 `db_debug_v*` 或 `db_production_v*` 目录。
    /// 注入测试根目录若不符合版本命名规则时，至少返回当前根目录。
    var allVersionDataRootDirectories: [URL] {
        StorageVersionedRootDiscovery.allRoots(containing: dataRootDirectory)
    }

    /// 默认实现放在 ProviderStorage 中，避免各个 StorageProviding 实现重复处理文件遍历。
    /// 文件扫描在 utility 优先级的后台任务执行，不阻塞设置页面的主线程。
    func dataRootDirectorySizeInBytes() async -> Int64 {
        let rootPaths = allVersionDataRootDirectories.map(\.path)
        return await Task.detached(priority: .utility) {
            StorageDirectorySizeCalculator.calculate(atPaths: rootPaths)
        }.value
    }
}

/// 在 Provider 创建前迁移一个基础设施的插件目录。
///
/// 启用状态、工具调用记录等数据会在 ProviderFactory 装配阶段就被读取，
/// 因此不能依赖稍后才执行的插件 `onBoot`。该入口与插件迁移使用同一套
/// 版本发现和复制规则，旧目录保留不动。
@MainActor
public enum StorageDataMigration {
    public static let currentMajorVersion = 6

    public static func migrate(
        storage: any StorageProviding,
        pluginID: String,
        legacyDirectoryNames: [String]
    ) throws {
        let currentRoot = storage.dataRootDirectory.standardizedFileURL
        let legacyRoots = storage.allVersionDataRootDirectories
            .filter { $0.standardizedFileURL != currentRoot }
            .reduce(into: [Int: URL]()) { result, root in
                guard let marker = root.lastPathComponent.range(of: "_v", options: .backwards),
                      let version = Int(root.lastPathComponent[marker.upperBound...]) else {
                    return
                }
                result[version] = root
            }
        let context = PluginDataMigrationContext(
            pluginID: pluginID,
            currentMajorVersion: currentMajorVersion,
            currentDataRootDirectory: currentRoot,
            legacyDataRootDirectories: legacyRoots
        )
        try PluginDataMigrationUtility.copyLegacyDirectories(
            legacyDirectoryNames: legacyDirectoryNames,
            context: context
        )
    }
}

/// 在宿主启动插件前执行整套插件数据迁移。
///
/// 这个 Runner 放在 ProviderStorage 中，而不是某个具体应用 Factory 中，
/// 这样 Lumi 主应用和专用宿主（例如 BookletMaker / AppIconDesigner）都能
/// 使用同一套迁移时序与目录发现规则。
@MainActor
public struct PluginDataMigrationRunner {
    public static let currentMajorVersion = 6

    private let storage: any StorageProviding

    public init(storage: any StorageProviding) {
        self.storage = storage
    }

    public func run(for plugins: [any SuperPlugin]) throws {
        for plugin in plugins {
            let context = context(for: plugin.id)
            guard let migrator = plugin as? any PluginDataMigrating else {
                guard let context else { continue }
                try PluginDataMigrationUtility.copyLegacyDirectories(
                    legacyDirectoryNames: [],
                    context: context
                )
                continue
            }
            guard let context else { continue }
            try migrator.migrateData(context: context)
        }
    }

    private func context(for pluginID: String) -> PluginDataMigrationContext? {
        let currentRoot = storage.dataRootDirectory.standardizedFileURL
        let legacyRoots = storage.allVersionDataRootDirectories
            .filter { $0.standardizedFileURL != currentRoot }
            .reduce(into: [Int: URL]()) { result, root in
                guard let version = Self.majorVersion(from: root.lastPathComponent) else { return }
                result[version] = root
            }

        return PluginDataMigrationContext(
            pluginID: pluginID,
            currentMajorVersion: Self.currentMajorVersion,
            currentDataRootDirectory: currentRoot,
            legacyDataRootDirectories: legacyRoots
        )
    }

    private static func majorVersion(from rootName: String) -> Int? {
        guard let marker = rootName.range(of: "_v", options: .backwards) else { return nil }
        return Int(rootName[marker.upperBound...])
    }
}

private enum StorageVersionedRootDiscovery {
    static func allRoots(containing currentRoot: URL) -> [URL] {
        let currentRoot = currentRoot.standardizedFileURL
        let currentName = currentRoot.lastPathComponent
        let prefix: String
        if currentName.hasPrefix("db_debug_v") {
            prefix = "db_debug_v"
        } else if currentName.hasPrefix("db_production_v") {
            prefix = "db_production_v"
        } else {
            return [currentRoot]
        }

        let parent = currentRoot.deletingLastPathComponent()
        let roots = (try? FileManager.default.contentsOfDirectory(
            at: parent,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ))?.filter { url in
            guard url.hasDirectoryPath else { return false }
            let name = url.lastPathComponent
            return name.hasPrefix(prefix) && Int(name.dropFirst(prefix.count)) != nil
        } ?? []

        var uniqueRoots: [URL] = []
        var seenPaths = Set<String>()
        for root in roots + [currentRoot] {
            let normalizedRoot = root.standardizedFileURL
            if seenPaths.insert(normalizedRoot.path).inserted {
                uniqueRoots.append(normalizedRoot)
            }
        }

        return uniqueRoots.sorted {
            version(of: $0, prefix: prefix) == version(of: $1, prefix: prefix)
                ? $0.path < $1.path
                : version(of: $0, prefix: prefix) < version(of: $1, prefix: prefix)
        }
    }

    private static func version(of url: URL, prefix: String) -> Int {
        Int(url.lastPathComponent.dropFirst(prefix.count)) ?? Int.max
    }
}

private enum StorageDirectorySizeCalculator {
    static func calculate(atPaths paths: [String]) -> Int64 {
        paths.reduce(into: Int64(0)) { total, path in
            let size = calculate(atPath: path)
            if total > Int64.max - size {
                total = Int64.max
            } else {
                total += size
            }
        }
    }

    private static func calculate(atPath path: String) -> Int64 {
        let rootURL = URL(fileURLWithPath: path, isDirectory: true)
        let resourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey,
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: resourceKeys),
                  values.isRegularFile == true else {
                continue
            }

            let size = Int64(
                values.totalFileAllocatedSize
                    ?? values.fileAllocatedSize
                    ?? values.fileSize
                    ?? 0
            )
            total = total.addingReportingOverflow(size).overflow
                ? Int64.max
                : total + size
        }
        return total
    }
}
