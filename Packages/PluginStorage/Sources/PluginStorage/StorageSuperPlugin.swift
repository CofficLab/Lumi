import Foundation
import KernelCore
import ProviderStorage
import KitSuperLog
import os

// MARK: - Storage SuperPlugin

/// 存储插件
///
/// 创建数据根目录并注册 `StorageService`（`StorageProviding` 实现）。
/// 路径格式：<Application Support>/<bundleID>/db_<debug|production>_v<majorVersion>
@MainActor
public final class StorageSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.storage", category: "Storage")
    public let id = "com.coffic.lumi.plugin.storage"
    public let order = 1
    /// 紧随 order 0 的基础插件之后启动。
    ///
    /// `StorageProviding` 是绝大多数插件的基础设施：多个插件在 `onBoot` 中解析它，
    /// 其中 `OnboardingPlugin`（order=10）与 `AgentPlanStoragePlugin`（order=81）
    /// 更是硬依赖（解析不到即抛错）。因此本插件必须早于所有消费者启动。
    ///
    /// 这里不能沿用默认的 order 200：那样 storage 会排在上述消费者之后。
    /// 首次装配时该问题被 `ProviderFactory` 预注册的 `DefaultStorageProvider`
    /// 掩盖（解析得到的是它），但 `kernel.stop()` 会一并移除该默认实现，
    /// 之后重新 `start(plugins:)` 时 storage 尚未注册，消费者 `onBoot` 直接失败。
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.storage",
        name: "Storage Super",
        description: "",
        category: .system,
        stage: .stable,
        policy: .alwaysOn
    )


    /// 数据根目录
    public let dataRootDirectory: URL

    public init(dataRootDirectory: URL? = nil) throws {
        if let dataRootDirectory {
            self.dataRootDirectory = dataRootDirectory
        } else {
            self.dataRootDirectory = try Self.makeDefaultDataRootDirectory()
        }
    }

    public convenience init() throws {
        try self.init(dataRootDirectory: nil)
    }

    // MARK: - Lifecycle

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 宿主或其它插件可能已装配了更合适的实现（自定义数据根目录、沙盒等），
        // 此时本插件让位于它，避免用默认路径覆盖掉宿主的隔离配置。
        if let existing = kernel.resolveProvider((any StorageProviding).self) {
            Self.logger.info("\(Self.t)StorageProviding already registered (\(String(describing: type(of: existing)), privacy: .public)), keeping it")
            return
        }

        let service = StorageService(dataRootDirectory: dataRootDirectory)
        try kernel.registerProvider((any StorageProviding).self, service)
    }

    // MARK: - Factory

    private static func makeDefaultDataRootDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.Lumi"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4"
        let majorVersion = version.split(separator: ".").first.flatMap { Int($0) } ?? 4

        #if DEBUG
        let dbDirectoryName = "db_debug_v\(majorVersion)"
        #else
        let dbDirectoryName = "db_production_v\(majorVersion)"
        #endif

        let dataRoot = appSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent(dbDirectoryName, isDirectory: true)

        try FileManager.default.createDirectory(at: dataRoot, withIntermediateDirectories: true)
        return dataRoot
    }
}

// MARK: - StorageService

/// 存储服务实现
@MainActor
public final class StorageService: StorageProviding {
    public let dataRootDirectory: URL

    public init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory.standardizedFileURL
    }

    public func pluginDataDirectory(for pluginID: String) -> URL {
        let pluginDir = dataRootDirectory
            .appendingPathComponent(pluginID, isDirectory: true)

        try? FileManager.default.createDirectory(
            at: pluginDir,
            withIntermediateDirectories: true
        )

        return pluginDir
    }

    public func coreDataDirectory() -> URL {
        let coreDir = dataRootDirectory
            .appendingPathComponent("Core", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: coreDir,
            withIntermediateDirectories: true
        )

        return coreDir
    }
}
