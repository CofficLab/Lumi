import os
import Foundation
import KernelCore
import KitSuperLog
import ProviderChatSection
import ProviderLLMManager
import ProviderStorage

/// Model Selector 插件（KernelCore 体系）。
///
/// 由旧版 `Plugins/ModelSelectorPlugin`（KernelLumi / LumiPlugin 架构）复刻而来：
/// - 在 Chat 分区 Action Bar 的 leading 位置注册模型选择按钮（`ActionBarButton`）；
/// - 按钮标签实时显示「当前供应商 + 模型」；
/// - 点击弹出供应商 + 模型浏览器（云端/本地 + 搜索）；
/// - 供应商/模型的选中与注册状态**完全直连内核 `LLMManaging` 读写**
///   （`resolveProvider` + `select(providerID:model:)`），无旧版通知订阅。
///
/// 与旧版的对应关系：
/// - `chatSectionActionBarItems(.leading)` → `ChatSectionProviding.addBarItems(.actionLeading)`；
/// - `kernel.resolveService((any LLMProviderManaging).self)` → 内核
///   `kernel.resolveProvider((any LLMManaging).self)`（FactoryLumi 已装配 `DefaultLLMManager`）；
/// - 旧版 `.onLumiSelectedRemoteProviderIDDidChange` 等通知订阅 → SwiftUI 友好包装器
///   `ObservableLLMProviderManagerBox`（订阅 `LLMManaging.addObserver` 事件）。
@MainActor
public final class ModelSelectorPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.model-selector", category: "ModelSelector")

    /// 保持旧版插件 ID，插件启用状态 / 存储 / 自动化不失效。
    public let id = "com.coffic.lumi.plugin.model-selector"
    public let order = 82
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.model-selector",
        name: "Model Selector",
        description: "",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )

    private var usageStore: ProviderUsageStore?

    public init() {}

    public var name: String {
        LumiPluginLocalization.string("Model Selector", bundle: .module)
    }


    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let manager = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding, LLMManaging from kernel")
            return
        }

        let usageStore: ProviderUsageStore
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            usageStore = ProviderUsageStore(
                directory: storage.pluginDataDirectory(for: id)
            )
        } else {
            Self.logger.warning("\(Self.t)StorageProviding unavailable; provider usage will not be persisted")
            usageStore = ProviderUsageStore(directory: nil)
        }
        self.usageStore = usageStore

        let box = ObservableLLMProviderManagerBox(manager: manager)

        // Action Bar 模型选择按钮（沿用旧版 chatSectionActionBarItems .leading）。
        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).action-bar-button",
                placement: .actionLeading
            ) {
                ActionBarButton(box: box, usageStore: usageStore)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).action-bar-button")
    }
}
