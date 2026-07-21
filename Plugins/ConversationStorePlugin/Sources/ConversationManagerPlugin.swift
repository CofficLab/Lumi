import Foundation
import LumiKernel
import SuperLogKit
import os

/// Conversation Store Plugin
///
/// Implements ConversationManaging protocol with SwiftData persistence.
@MainActor
public final class ConversationStorePlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-store")
    nonisolated public static let emoji = "💬"
    public static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.conversation-store"
    public let name = "Conversation Store"
    public let order = 61

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        let manager = ConversationManager(kernel: kernel)
        kernel.registerConversations(manager)

        // Register initial (empty) state - will be loaded properly in boot()
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 ConversationManager")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // Initialize ConversationStore with proper database root URL
        let databaseRootURL: URL
        let dataDirectory: URL

        if let storage = kernel.storage {
            databaseRootURL = storage.dataRootDirectory
            dataDirectory = storage.dataRootDirectory
        } else {
            databaseRootURL = ConversationStore.defaultDatabaseRootURL
            dataDirectory = ConversationStore.defaultDatabaseRootURL
        }

        do {
            let store = try ConversationStore(databaseRootURL: databaseRootURL)
            ConversationManagerRuntimeBridge.shared.store = store
            ConversationManagerRuntimeBridge.shared.dataDirectory = dataDirectory

            // Load conversations into the manager
            if let manager = kernel.conversations as? ConversationManager {
                manager.loadConversations()
            }

            if Self.verbose {
                Self.logger.info("\(Self.t)ConversationStorePlugin 启动完成，数据库路径: \(databaseRootURL.path)")
            }
        } catch {
            throw ConversationStoreError.initializationFailed("ConversationStorePlugin 数据库初始化失败: \(error.localizedDescription)")
        }
    }
}
