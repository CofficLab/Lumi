import Foundation
import MemoryKit

/// 记忆存储服务。
///
/// 包装 MemoryKit 的 MemoryStorageService，配置从 `MemoryPlugin.config` 读取。
public actor MemoryStorageService {
    public static let shared = MemoryStorageService()

    private let service: MemoryKit.MemoryStorageService

    /// 暴露底层 MemoryKit 服务（供 MemoryRetrievalService 使用）
    public var memoryKitStorage: MemoryKit.MemoryStorageService { service }

    private init() {
        let config = MemoryPlugin.config
        let rootURL = config.memoryRootURL
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        self.service = MemoryKit.MemoryStorageService(
            rootURL: rootURL,
            verbose: MemoryPlugin.verbose
        )
    }

    public func createMemory(
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

    public func readMemory(id: String, scope: MemoryScope) async throws -> MemoryItem {
        try await service.readMemory(id: id, scope: scope)
    }

    public func updateMemory(
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

    public func deleteMemory(id: String, scope: MemoryScope) async throws {
        try await service.deleteMemory(id: id, scope: scope)
    }

    public func listMemories(scope: MemoryScope) async -> [MemoryItem] {
        await service.listMemories(scope: scope)
    }

    public func readIndex(scope: MemoryScope) async -> String {
        await service.readIndex(scope: scope)
    }

    public func rebuildIndex(scope: MemoryScope) async throws {
        try await service.rebuildIndex(scope: scope)
    }
}
