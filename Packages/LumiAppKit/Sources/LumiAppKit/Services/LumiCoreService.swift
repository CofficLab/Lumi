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

    /// 工具/子 Agent 贡献源（App 层的 PluginService）。保留引用以便运行期
    /// 插件启用状态变化时由 App 层重新触发 `bootstrapToolContributions`。
    private let provider: any LumiAgentToolProviding

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
        self.provider = provider

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

        // boot 完成后编排工具贡献：把插件工具 / 内置工具 / 子 Agent 工具注册进 ToolService，
        // 并把 ToolService 关联到 ChatService。LLM Provider / 中间件 / 渲染器等 Chat 维度
        // 的贡献由 ChatService.applyPluginContributions 处理（由 RootContainer 在本方法
        // 返回后调用）。工具名唯一性已在 boot 阶段校验，此处直接注册。
        bootstrapToolContributions()
    }

    /// 重新编排工具贡献。运行期插件启用状态变化时由 App 层调用，
    /// 让新启用插件贡献的工具 / 子 Agent 进入 ToolService。
    func bootstrapToolContributions() {
        let context = lumiCore.makePluginContext(
            activeSectionID: "chat.core",
            activeSectionTitle: "Chat Core"
        )
        lumiCore.bootstrapToolContributions(
            provider: provider,
            context: context,
            builtInTools: ChatService.builtInTools
        )
    }
}
