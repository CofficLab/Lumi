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

    let lumiCore: LumiCore
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

        // 创建 LumiCore 实例
        self.lumiCore = LumiCore()

        // 设置 ChatService 工厂，boot() 时自动创建并注册
        lumiCore.setupChatService { [weak self] databaseDirectory in
            ChatService(configuration: .coreDatabase(directory: databaseDirectory), lumiCore: self?.lumiCore)
        }

        try lumiCore.boot(
            dataRootDirectory: dataRootDirectory,
            provider: provider,
            builtInTools: ChatService.builtInTools,
            editorFactory: editorFactory
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)数据根目录: \(dataRootDirectory.path)")
            Self.logger.info("\(Self.t)核心数据库目录: \(self.coreDatabaseDirectory.path)")
            Self.logger.info("\(Self.t)✅ LumiCoreService 初始化完成")
        }

        // 把自己注册为"当前活跃"的 LumiCore,让无法接收 LumiPluginContext 的静态
        // 单例(Plugin 的 LocalStore 等)能拿到存储路径。两个别名(MainActor 上下文用
        // `LumiCore.current`,非 MainActor 上下文用模块级 `currentLumiCore`)指向同一份
        // 引用,保持单一事实源。
        //
        // `currentLumiCoreDataRootDirectory` 是 `lumiCore.dataRootDirectory` 的 nonisolated
        // 镜像：plugin 侧 `static let shared = ...` 单例 init 经常发生在非 MainActor 上下文，
        // 直接读协议 `dataRootDirectory` 会撞 MainActor 隔离。镜像让 plugin 不用关心这点。
        LumiCore.current = lumiCore
        currentLumiCore = lumiCore
        currentLumiCoreDataRootDirectory = lumiCore.dataRootDirectory
    }
}
