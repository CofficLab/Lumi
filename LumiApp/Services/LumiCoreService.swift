import Foundation
import LumiChatKit
import LumiCoreKit
import SuperLogKit
import os

@MainActor
final class LumiCoreService: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.lumi-core")
    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    let dataRootDirectory: URL
    let coreDatabaseDirectory: URL

    /// 初始化 `LumiCoreService` 并启动 `LumiCore`。
    ///
    /// 启动期会调用 `LumiCore.boot(provider:databaseDirectory:editorFactory:)`，LumiCore 内部
    /// 通过 `provider` 校验当前启用的所有 Agent Tool 名称唯一性。重复时会抛出
    /// `LumiToolRegistrationError`，由调用方（如 `RootContainer`）捕获并以
    /// `CrashedView` 展示，避免运行时 `fatalError` 闪退。
    ///
    /// `editorFactory` 透传给 `LumiCore.boot`：LumiCore 会在工具服务就绪后调用工厂创建
    /// `EditorService`，并自动注册抽象协议（`AbstractEditorServicing`）与具体类型到服务表。
    ///
    /// - Parameters:
    ///   - provider: Agent Tool 贡献者（通常是 `PluginService`）。
    ///   - editorFactory: Editor 工厂闭包，接收 provider，返回具体的 `EditorService` 实例。
    init<Service: AbstractEditorServicing>(
        provider: any LumiAgentToolProviding,
        editorFactory: LumiCore.EditorBootstrapFactory<Service>
    ) throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化 LumiCoreService")
        }

        let dataRootDirectory = Self.makeDataRootDirectory()
        self.dataRootDirectory = dataRootDirectory
        self.coreDatabaseDirectory = Self.makeCoreDatabaseDirectory(in: dataRootDirectory)

        // 设置 ChatService 工厂，LumiCore.boot() 时自动创建并注册
        LumiCore.setupChatService { databaseDirectory in
            ChatService(configuration: .coreDatabase(directory: databaseDirectory))
        }

        // 启动 LumiCore（自动创建 ChatService / ToolService / EditorService 并注册到服务表）。
        // 启动期工具名校验在 boot 内部完成，重复时直接抛 LumiToolRegistrationError。
        try LumiCore.boot(
            databaseDirectory: self.coreDatabaseDirectory,
            provider: provider,
            editorFactory: editorFactory
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)数据根目录: \(dataRootDirectory.path)")
            Self.logger.info("\(Self.t)核心数据库目录: \(self.coreDatabaseDirectory.path)")
            Self.logger.info("\(Self.t)✅ LumiCoreService 初始化完成")
        }
    }

    /// Fallback 用最小初始化：只解析数据目录，不启动 `LumiCore`。
    ///
    /// 用于 `RootContainer` 启动失败后构造退化的 `LumiCoreService` 占位实例，
    /// 让 `CrashedView` 能够显示。**不会**调起 `LumiCore.boot`，因此也不进行
    /// Agent Tool 重复校验——避免错误处理路径上再次崩溃，掩盖原始错误。
    static func fallbackStub() -> LumiCoreService {
        if Self.verbose {
            Self.logger.info("\(Self.t)构造 LumiCoreService fallback stub")
        }
        let dataRootDirectory = Self.makeDataRootDirectory()
        let coreDatabaseDirectory = Self.makeCoreDatabaseDirectory(in: dataRootDirectory)
        return LumiCoreService(
            dataRootDirectory: dataRootDirectory,
            coreDatabaseDirectory: coreDatabaseDirectory
        )
    }

    /// 仅由 `fallbackStub()` 调用的私有初始化器，跳过 `LumiCore.boot`。
    private init(dataRootDirectory: URL, coreDatabaseDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory
        self.coreDatabaseDirectory = coreDatabaseDirectory
    }

    // MARK: - Private

    private static func makeDataRootDirectory() -> URL {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to resolve Application Support directory.")
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.Lumi"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)
        let versionSuffix = "v\(majorVersion(from: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String))"

        #if DEBUG
        let databaseDirectoryName = "db_debug_\(versionSuffix)"
        #else
        let databaseDirectoryName = "db_production_\(versionSuffix)"
        #endif

        let dataRootDirectory = appDirectory.appendingPathComponent(databaseDirectoryName, isDirectory: true)
        try? fileManager.createDirectory(
            at: dataRootDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return dataRootDirectory
    }

    private static func makeCoreDatabaseDirectory(in dataRootDirectory: URL) -> URL {
        let coreDirectory = dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: coreDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return coreDirectory
    }

    private static func majorVersion(from version: String?) -> Int {
        guard let version,
              let major = version.split(separator: ".").first,
              let value = Int(major)
        else {
            return 1
        }

        return value
    }
}