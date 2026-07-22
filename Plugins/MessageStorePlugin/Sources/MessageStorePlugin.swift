import Foundation
import LumiKernel

/// Message Store Plugin
///
/// Implements MessageManaging protocol with SwiftData persistence.
@MainActor
public final class MessageStorePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.message-store"
    public let name = "Message Store"
    public let order = 62  // After ConversationStorePlugin

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        let manager = MessageManager(kernel: kernel)
        kernel.registerMessageManager(manager)
    }

    public func boot(kernel: LumiKernel) async throws {
        // Initialize MessageStore with proper database root URL
        let databaseRootURL: URL
        if let storage = kernel.storage {
            databaseRootURL = storage.dataRootDirectory
        } else {
            databaseRootURL = MessageStore.defaultDatabaseRootURL
        }

        do {
            let store = try MessageStore(databaseRootURL: databaseRootURL)
            MessageStoreRuntimeBridge.shared.store = store
        } catch {
            throw MessageStoreError.initializationFailed("MessageStorePlugin 数据库初始化失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - Runtime Bridge

@MainActor
final class MessageStoreRuntimeBridge: @unchecked Sendable {
    static let shared = MessageStoreRuntimeBridge()

    var store: MessageStore?

    private init() {}
}
