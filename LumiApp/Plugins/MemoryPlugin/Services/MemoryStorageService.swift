import Foundation
import MemoryKit

/// App 层记忆存储服务适配器
///
/// 提供 `shared` 单例接口，内部委托给 MemoryKit 的 MemoryStorageService。
/// 存储路径由 AppConfig.getDBFolderURL() 决定。
actor MemoryStorageService {
    static let shared = MemoryStorageService()

    private let service: MemoryKit.MemoryStorageService

    /// 暴露底层 MemoryKit 服务（供 MemoryRetrievalService 使用）
    var memoryKitStorage: MemoryKit.MemoryStorageService { service }

    private init() {
        let rootURL = AppConfig.getDBFolderURL()
            .appendingPathComponent("Memory", isDirectory: true)
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        self.service = MemoryKit.MemoryStorageService(
            rootURL: rootURL,
            verbose: MemoryPluginLocalStore.shared.isVerbose
        )
    }

    // MARK: - 委托 API（与 App 层现有调用签名一致）

    func createMemory(
        id: String,
        type: MemoryType,
        name: String,
        description: String,
        content: String,
        scope: MemoryScope
    ) async throws -> MemoryItem {
        try await service.createMemory(
            id: id, type: type, name: name,
            description: description, content: content, scope: scope
        )
    }

    func readMemory(id: String, scope: MemoryScope) async throws -> MemoryItem {
        try await service.readMemory(id: id, scope: scope)
    }

    func updateMemory(
        id: String,
        name: String? = nil,
        description: String? = nil,
        content: String? = nil,
        scope: MemoryScope
    ) async throws -> MemoryItem {
        try await service.updateMemory(
            id: id, name: name, description: description,
            content: content, scope: scope
        )
    }

    func deleteMemory(id: String, scope: MemoryScope) async throws {
        try await service.deleteMemory(id: id, scope: scope)
    }

    func listMemories(scope: MemoryScope) async -> [MemoryItem] {
        await service.listMemories(scope: scope)
    }

    func readIndex(scope: MemoryScope) async -> String {
        await service.readIndex(scope: scope)
    }

    func rebuildIndex(scope: MemoryScope) async throws {
        try await service.rebuildIndex(scope: scope)
    }
}
