import Foundation
import LumiKernel
import os
import SuperLogKit

/// Message Send Manager Plugin
///
/// Registers a `MessageSendManaging` implementation with the kernel.
/// The implementation lives in `Managers/MessageSendManager.swift`
/// and persists the user message into `MessageManaging` before
/// dispatching the conversation history to the first registered
/// LLM provider and writing the assistant message back.
@MainActor
public final class MessageSendManagerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-send-manager")
    public nonisolated static let emoji = "📤"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.message-send-manager"
    public let name = "Message Send Manager"
    public let order = 63  // After MessageStorePlugin (62)
    public static let policy: LumiPluginPolicy = .disabled // 核心插件

    // MARK: - Initialization

    public init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)MessageSendManagerPlugin")
        }
    }

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        let service = MessageSendManager(kernel: kernel)
        kernel.registerMessageSend(service)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 MessageSendManager")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)MessageSendManagerPlugin boot 完成")
        }
    }
}
