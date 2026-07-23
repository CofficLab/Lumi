import Foundation
import LumiKernel
import SuperLogKit
import os

/// ChatKernel 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑
@MainActor
public struct ChatKernelOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        let chatService = ChatService()
        kernel.registerChat(chatService)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Chat 服务")
        }
    }
}
