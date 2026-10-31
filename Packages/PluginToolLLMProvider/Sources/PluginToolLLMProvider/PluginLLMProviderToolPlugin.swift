import Foundation
import KernelCore
import KitAgentTool
import LumiLoggingKit
import ProviderLLMManager
import ProviderMessageRendering
import ProviderToolManager
import os

/// 「用对话添加 LLM 供应商」插件。
///
/// 组成两条链路：
/// - **工具链路**：注册 `add_llm_provider`，让 LLM 能把新供应商整理成提案；
/// - **渲染链路**：注册 `LLMProviderRowRenderer`，把工具结果渲染成可确认的卡片。
///
/// ## 启动顺序
///
/// `order = 120` 大于供应商设置插件（100）：自定义供应商的 Store 正是在
/// 那里注册进内核的，必须先于本插件完成注册，否则卡片拿不到落库能力。
///
/// ## 副作用边界
///
/// 插件本身不写盘、不注册供应商。真正落库发生在用户点击卡片上的「添加」时。
@MainActor
public final class PluginLLMProviderToolPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.tool-llm-provider",
        category: "PluginLLMProviderToolPlugin"
    )

    public let id = "com.coffic.lumi.plugin.tool-llm-provider"

    /// 必须晚于 `com.coffic.lumi.plugin.llm-provider-settings`（order 100）。
    public let order = 120

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.tool-llm-provider",
        name: "LLM Provider Tool",
        description: "",
        category: .llm,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        registerTool(kernel: kernel)
        registerRenderer(kernel: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ToolCallRenderingProviding).self)?
            .unregister(id: LLMProviderRowRenderer.id)
        kernel.resolveProvider((any ToolManagerProviding).self)?
            .remove(id: AddLLMProviderTool.toolName)
    }

    // MARK: - 工具

    /// 注册 `add_llm_provider` 工具。
    private func registerTool(kernel: KernelCoreContainer) {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding; add_llm_provider was not registered")
            return
        }
        toolManager.add(AddLLMProviderTool(), pluginID: id)
    }

    // MARK: - 渲染器

    /// 注册工具结果渲染器。
    ///
    /// 渲染器需要两个能力：自定义供应商 Store（落库）与 LLM 管理器（切换选中）。
    /// 任一缺失时仍注册渲染器——卡片会显示「服务不可用」而不是静默消失。
    private func registerRenderer(kernel: KernelCoreContainer) {
        guard let rendering = kernel.resolveProvider((any ToolCallRenderingProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolCallRenderingProviding; the proposal card will fall back to the default tool row")
            return
        }

        let store = kernel.resolveProvider((any UserDefinedCloudProviderStoreProviding).self)?.store
        if store == nil {
            Self.logger.warning("\(Self.t)UserDefinedCloudProviderStoreProviding is unavailable; the proposal card cannot save the provider")
        }
        let manager = kernel.resolveProvider((any LLMManaging).self)

        rendering.register(
            LLMProviderRowRenderer(
                store: store,
                manager: manager
            )
        )
    }
}
