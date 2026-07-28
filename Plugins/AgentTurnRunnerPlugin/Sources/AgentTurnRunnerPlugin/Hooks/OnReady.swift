import Foundation
import LumiKernel
import SuperLogKit
import os

/// AgentTurnRunner 插件 OnReady 阶段钩子
///
/// AgentTurnRunner 服务的注册已在 OnBoot 阶段完成。本钩子负责初始化
/// 「发出的请求」记录的 SwiftData 存储,数据目录沿用与 ConversationStore 一致的
/// `kernel.storage.pluginDataDirectory(for:)` 规律。
@MainActor
public struct AgentTurnRunnerOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-turn-runner")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        guard let storage = kernel.storage else {
            if Self.verbose {
                Self.logger.warning("AgentTurnRunner onReady: kernel.storage 不可用,跳过请求记录存储初始化")
            }
            return
        }
        let dataDirectory = storage.pluginDataDirectory(for: "AgentTurnRunner")
        let store = AgentTurnRecordStore(databaseRootURL: dataDirectory)
        AgentTurnRunnerRecordStoreBridge.shared.store = store
        AgentTurnRunnerRecordStoreBridge.shared.dataDirectory = dataDirectory
        if Self.verbose {
            Self.logger.info("AgentTurnRunner onReady: 请求记录存储已初始化 dataDirectory=\(dataDirectory.path)")
        }
    }
}
