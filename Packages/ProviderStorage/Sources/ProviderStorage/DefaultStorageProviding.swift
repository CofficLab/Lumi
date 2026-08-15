import Foundation

/// `StorageProviding` 的默认实现：基于应用支持目录（Application Support）
/// 的磁盘存储。
///
/// 目录结构：
/// - 数据根目录：`~/Library/Application Support/<appName>/`
/// - 插件数据目录：`<root>/Plugins/<pluginID>/`
/// - 核心数据目录：`<root>/Core/`
///
/// 所有目录按需创建（`createDirectory`）。
@MainActor
public final class DefaultStorageProviding: StorageProviding {
    /// 应用名称；用于构造 Application Support 子目录。默认取主 bundle 名。
    private let appName: String

    public init(appName: String? = nil) {
        self.appName = appName ?? Self.defaultAppName
    }

    /// 数据根目录：`~/Library/Application Support/<appName>/`
    public lazy var dataRootDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let root = base.appendingPathComponent(appName, isDirectory: true)
        Self.ensureDirectory(root)
        return root
    }()

    /// 插件数据目录：`<root>/Plugins/<pluginID>/`
    public func pluginDataDirectory(for pluginID: String) -> URL {
        let dir = dataRootDirectory
            .appendingPathComponent("Plugins", isDirectory: true)
            .appendingPathComponent(pluginID, isDirectory: true)
        Self.ensureDirectory(dir)
        return dir
    }

    /// 核心数据目录：`<root>/Core/`
    public func coreDataDirectory() -> URL {
        let dir = dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
        Self.ensureDirectory(dir)
        return dir
    }

    // MARK: - Helpers

    /// 默认应用名：主 bundle 的显示名或 bundle 标识，回退到 "Lumi"。
    private static var defaultAppName: String {
        let bundle = Bundle.main
        if let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !name.isEmpty {
            return name
        }
        if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String, !name.isEmpty {
            return name
        }
        if let id = bundle.bundleIdentifier, !id.isEmpty {
            return id
        }
        return "Lumi"
    }

    /// 确保目录存在（不存在则创建）。
    private static func ensureDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
