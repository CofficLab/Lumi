import Foundation
import LumiKernel
import os

/// 消息渲染器管理插件
///
/// 唯一实现 MessageRendererManaging 协议，负责管理所有已注册的消息渲染器。
@MainActor
public final class MessageRendererManagerPlugin: LumiPlugin {
    nonisolated public static let emoji = "🎨"
    nonisolated public static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.message-renderer-manager"
    public let name = "MessageRendererManager Plugin"
    public let order = 4
    public static let policy: LumiPluginPolicy = .disabled  // 核心插件，最先注册

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onReady(kernel: LumiKernel) throws {
        kernel.registerMessageRendererManagerService(MessageRendererManager.shared)

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 MessageRendererManager 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)MessageRendererManager 插件启动完成")
        }
    }
}

// MARK: - Logger Extension

extension MessageRendererManagerPlugin {
    nonisolated private static var logger: Logger {
        Logger(subsystem: "com.coffic.lumi", category: "plugin.message-renderer-manager")
    }

    nonisolated private static var t: String {
        "\(Self.emoji)[\(Self.self)]"
    }
}
