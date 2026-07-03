import Foundation
import LumiChatKit
import LumiCoreKit
import SuperLogKit
import os

@MainActor
final class LumiCoreService: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.lumi-core")
    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = true

    let dataRootDirectory: URL
    let coreDatabaseDirectory: URL

    init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化 LumiCoreService")
        }

        let dataRootDirectory = Self.makeDataRootDirectory()
        AppConfig.configure(dataRootDirectory: dataRootDirectory)
        self.dataRootDirectory = dataRootDirectory
        self.coreDatabaseDirectory = Self.makeCoreDatabaseDirectory(in: dataRootDirectory)

        // 设置 ChatService 工厂，LumiCore.boot() 时自动创建并注册
        LumiCore.setupChatService { databaseDirectory in
            ChatService(configuration: .coreDatabase(directory: databaseDirectory))
        }

        // 启动 LumiCore（自动创建 ChatService 并注册到服务表）
        LumiCore.boot(databaseDirectory: self.coreDatabaseDirectory)

        if Self.verbose {
            Self.logger.info("\(Self.t)数据根目录: \(dataRootDirectory.path)")
            Self.logger.info("\(Self.t)核心数据库目录: \(self.coreDatabaseDirectory.path)")
            Self.logger.info("\(Self.t)✅ LumiCoreService 初始化完成")
        }
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
