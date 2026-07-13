import Foundation
import LumiChatKit
import LumiCoreKit
import os
import SuperLogKit

@MainActor
final class LumiCoreService: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.lumi-core")
    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    let dataRootDirectory: URL
    let coreDatabaseDirectory: URL

    init<Service: AbstractEditorServicing>(
        provider: any LumiAgentToolProviding,
        editorFactory: @escaping LumiCore.EditorBootstrapFactory<Service>,
        dataRootDirectory: URL
    ) throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化 LumiCoreService")
        }

        self.dataRootDirectory = dataRootDirectory
        self.coreDatabaseDirectory = StorageService.makeCoreDatabaseDirectory(in: dataRootDirectory)

        // 设置 ChatService 工厂，LumiCore.boot() 时自动创建并注册
        LumiCore.setupChatService { databaseDirectory in
            ChatService(configuration: .coreDatabase(directory: databaseDirectory))
        }

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
}
