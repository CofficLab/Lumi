import Foundation
import LumiKernel
import os
import SuperLogKit

/// Message Sender Plugin
///
/// Registers a `MessageSendManaging` implementation with the kernel.
/// The implementation lives in `Managers/MessageSender.swift`
/// and persists the user message into `MessageManaging` before
/// delegating to `AgentTurnRunner` for the full agent loop.
@MainActor
public final class MessageSenderPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-sender")
    public nonisolated static let emoji = "📤"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.message-sender"
    public let name = "Message Sender"
    public let order = 63  // After MessageStorePlugin (62)
    public static let policy: LumiPluginPolicy = .alwaysOn

    // MARK: - Initialization

    public init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)MessageSenderPlugin")
        }
    }

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        let service = MessageSender(kernel: kernel)
        kernel.registerMessageSend(service)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 MessageSender")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)MessageSenderPlugin boot 完成")
        }
    }
}
