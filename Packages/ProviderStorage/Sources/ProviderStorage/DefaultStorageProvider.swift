import Foundation
import os
import KitSuperLog

/// `StorageProviding` 的默认实现
///
/// 目录结构：
/// - 数据根目录：`~/Library/Application Support/<bundleID>/db_<debug|production>_v<majorVersion>/`
/// - 插件数据目录：`<root>/<pluginID>/`（无 `Plugins/` 中间层）
/// - 核心数据目录：`<root>/Core/`
///
/// 所有目录按需创建（`createDirectory`）。
@MainActor
public final class DefaultStorageProvider: StorageProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.provider-storage", category: "ProviderStorage")
    nonisolated public static let emoji = "💾"
    nonisolated static let verbose = false

    /// 数据根目录
    public let dataRootDirectory: URL

    /// - Parameter dataRootDirectory: 数据根目录；不传时自动计算
    ///   （`~/Library/Application Support/<bundleID>/db_<debug|production>_v<majorVersion>/`）。
    public init(dataRootDirectory: URL? = nil) {
        if let dataRootDirectory {
            let root = dataRootDirectory.standardizedFileURL
            Self.ensureDirectory(root)
            self.dataRootDirectory = root
            if Self.verbose {
                Self.logger.info("\(self.t)ProviderStorage initialized with root: \(root.path, privacy: .public)")
            }
        } else {
            self.dataRootDirectory = Self.makeDefaultDataRootDirectory()
        }
    }

    /// 插件数据目录：`<root>/<pluginID>/`（与旧版 `StorageService` 一致，无 `Plugins/` 中间层）。
    public func pluginDataDirectory(for pluginID: String) -> URL {
        let dir = dataRootDirectory
            .appendingPathComponent(pluginID, isDirectory: true)
        Self.ensureDirectory(dir)
        if Self.verbose {
            Self.logger.debug("\(self.t)plugin data directory for \(pluginID): \(dir.path, privacy: .public)")
        }
        return dir
    }

    /// 核心数据目录：`<root>/Core/`
    public func coreDataDirectory() -> URL {
        let dir = dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
        Self.ensureDirectory(dir)
        if Self.verbose {
            Self.logger.debug("\(self.t)core data directory: \(dir.path, privacy: .public)")
        }
        return dir
    }

    // MARK: - Helpers

    /// 按旧版规范生成默认数据根目录：
    /// `<Application Support>/<bundleID>/db_<debug|production>_v<majorVersion>/`。
    ///
    /// 与旧版 `StoragePlugin.makeDefaultDataRootDirectory()` 完全一致：
    /// - bundleID：主 bundle 标识，回退 `com.coffic.Lumi`；
    /// - 环境名：DEBUG 构建 `db_debug_*`，Release 构建 `db_production_*`；
    /// - 主版本号：取 `CFBundleShortVersionString` 第一段，回退 4。
    public static func makeDefaultDataRootDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.Lumi"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4"
        let majorVersion = Self.majorVersion(from: version)

        #if DEBUG
        let dbDirectoryName = dataRootDirectoryName(debug: true, majorVersion: majorVersion)
        #else
        let dbDirectoryName = dataRootDirectoryName(debug: false, majorVersion: majorVersion)
        #endif

        let dataRoot = appSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent(dbDirectoryName, isDirectory: true)
        Self.ensureDirectory(dataRoot)
        if Self.verbose {
            Self.logger.info("\(Self.t)default data root computed: bundleID=\(bundleID, privacy: .public), version=\(version), majorVersion=\(majorVersion), dbDirectory=\(dbDirectoryName), root=\(dataRoot.path, privacy: .public)")
        }
        return dataRoot
    }

    /// 数据根目录名：`db_<debug|production>_v<majorVersion>`（与旧版命名规则一致）。
    static func dataRootDirectoryName(debug: Bool, majorVersion: Int) -> String {
        let environment = debug ? "debug" : "production"
        return "db_\(environment)_v\(majorVersion)"
    }

    /// 解析主版本号：`"5.3.1" -> 5`；无法解析时回退 4。
    static func majorVersion(from versionString: String) -> Int {
        versionString.split(separator: ".").first.flatMap { Int($0) } ?? 4
    }

    /// 确保目录存在（不存在则创建）。
    private static func ensureDirectory(_ url: URL) {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(Self.t)Failed to create directory \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
