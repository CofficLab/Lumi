import Foundation
import KernelCore
import ProviderChatSection
import ProviderLLMManager

/// Model Selector 插件（KernelCore 体系）。
///
/// 由旧版 `Plugins/ModelSelectorPlugin`（KernelLumi / LumiPlugin 架构）复刻而来：
/// - 在 Chat 分区 Action Bar 的 leading 位置注册模型选择按钮（`ActionBarButton`）；
/// - 点击弹出供应商 + 模型浏览器（云端/本地 + API 格式筛选 + 搜索）；
/// - 选中通过 `LLMProviderManagerProviding` 持久化并广播，发送链路即时生效。
///
/// 与旧版的对应关系：
/// - `chatSectionActionBarItems(.leading)` → `ChatSectionProviding.addBarItems(.actionLeading)`；
/// - `kernel.resolveService((any LLMProviderManaging).self)` → 内核
///   `LLMProviderManagerProviding`（FactoryLumi2 已装配 `DefaultLLMProviderManagerProviding`）；
/// - 旧版 `.onLumiSelectedRemoteProviderIDDidChange` 等通知订阅 → SwiftUI 友好包装器
///   `ObservableLLMProviderManagerBox`（桥接管理器 `objectWillChange`）。
@MainActor
public final class ModelSelectorPlugin: SuperPlugin {
    /// 保持旧版插件 ID，插件启用状态 / 存储 / 自动化不失效。
    public let id = "com.coffic.lumi.plugin.model-selector"
    public let order = 82

    public init() {}

    public var name: String {
        LumiPluginLocalization.string("Model Selector", bundle: .module)
    }

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Model Selector",
            description: "LLM provider and model selection in the chat composer toolbar",
            category: .chat,
            stage: .preview,
            policy: .alwaysOn
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let manager = kernel.resolveProvider((any LLMProviderManagerProviding).self) else {
            return
        }

        let box = ObservableLLMProviderManagerBox(manager: manager)

        // Action Bar 模型选择按钮（沿用旧版 chatSectionActionBarItems .leading）。
        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).action-bar-button",
                placement: .actionLeading
            ) {
                ActionBarButton(box: box)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).action-bar-button")
    }
}
