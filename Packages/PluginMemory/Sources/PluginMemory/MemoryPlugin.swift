import os
import Foundation
import KernelCore
import SuperLogKit
import ProviderStorage
import ProviderProject
import ProviderToolManager

/// 记忆插件：把重要信息持久化到记忆系统，供 Agent 在后续对话中调用。
///
/// 复刻自旧版 `Plugins/MemoryPlugin`：
/// - 存储目录遵循 Storage 约定：`<数据根目录>/Memory`；
/// - 注册 4 个 Agent 工具：save_memory / recall_memory / list_memories / delete_memory；
/// - 记忆文件为 Markdown（frontmatter 元数据 + 正文），按 global/projects 分目录。
@MainActor
public final class MemoryPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.memory", category: "Memory")

    /// 保持旧版插件 ID。
    public let id = "com.coffic.lumi.plugin.memory"
    public let order = 89

    private var storage: MemoryFileStorage?

    public init() {}

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Memory",
            description: "Persistent memory for the agent",
            category: .chat,
            stage: .preview,
            policy: .alwaysOn
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let storageProvider = kernel.resolveProvider((any StorageProviding).self),
              let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve StorageProviding, ToolManagerProviding from kernel")
            return
        }
        let memoryRoot = storageProvider.pluginDataDirectory(for: "Memory")
        let storage = MemoryFileStorage(rootURL: memoryRoot)
        self.storage = storage

        let project = kernel.resolveProvider((any ProjectProviding).self)
        toolManager.add(SaveMemoryTool(storage: storage, project: project), pluginID: id)
        toolManager.add(RecallMemoryTool(storage: storage, project: project), pluginID: id)
        toolManager.add(ListMemoriesTool(storage: storage, project: project), pluginID: id)
        toolManager.add(DeleteMemoryTool(storage: storage, project: project), pluginID: id)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }
        toolManager.remove(id: "save_memory")
        toolManager.remove(id: "recall_memory")
        toolManager.remove(id: "list_memories")
        toolManager.remove(id: "delete_memory")
        storage = nil
    }
}
