import Foundation
import os
import KernelCore
import ProviderLLMManager
import ProviderStorage
import ProviderChatSection
import KitLLM
import LumiLoggingKit
/// MiniMax 供应商装配插件（KernelCore 生态）。
///
/// 在 `onBoot` 中把本供应商的 MiniMaxOpenAIProvider() 注册进
/// `LLMProviderManagerProviding`，聊天链路即可经管理器路由到该供应商。
/// 三个协议变体共享同一批模型与 API Key，仅保留功能最完整的 OpenAI 协议变体，
/// Anthropic / Responses 变体现注释停用。
///
/// 同时在 chat 工具栏 trailing 注册 Token Plan 配额 chip
/// （`ChatSectionBarPlacement.toolbarTrailing`）。chip 的常驻与撤回由本插件负责，
/// 「仅当选中 MiniMax 时显示」由 ``MiniMaxSelectionGate`` 驱动。
///
/// 远程模型列表缓存由本插件自行维护，落盘在
/// `storage.pluginDataDirectory(for: pluginID)/models.json`。
@MainActor
public final class MiniMaxProviderPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.llm-provider.minimax", category: "MiniMax")
    nonisolated public static let emoji = "⚡"
    nonisolated static let verbose = false

    public static let pluginID = "com.coffic.lumi.plugin.llm-provider.minimax"

    public let id = MiniMaxProviderPlugin.pluginID
    public let order = 100
    public let metadata = PluginMetadata(
        id: MiniMaxProviderPlugin.pluginID,
        name: "MiniMax 供应商",
        description: "",
        category: .llm,
        stage: .stable,
        policy: .alwaysOn
    )

    /// chat 工具栏配额 chip 的贡献 id（`onShutdown` 据此撤回）。
    nonisolated static let toolbarItemID = "com.coffic.lumi.plugin.llm-provider.minimax.token-plan"

    private var tokenPlanViewModel: TokenPlanViewModel?
    private var selectionGate: MiniMaxSelectionGate?
    private var selectionObserver: MiniMaxSelectionObserver?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let manager = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve LLMProviderManagerProviding from kernel\(self.r("manager is nil"))")
            return
        }
        let networkProvider = kernel.resolveProvider((any LLMNetworkProviding).self)
        let apiService = VendorAPIService(networkProvider: networkProvider)

        // 绑定插件自有数据目录，供远程模型列表缓存落盘。
        let localStore = MiniMaxLocalStore()
        localStore.configure(storage: kernel.resolveProvider((any StorageProviding).self))

        // UI 测试模式（--lumi-ui-testing）：用桩网络与固定假 Key 装配，
        // 刷新返回固定 9 模型，不访问真实网络、不读用户 Keychain。
        #if DEBUG
        if MiniMaxUITestingSupport.isEnabled {
            let testProvider = MiniMaxUITestingSupport.makeProvider(modelListCache: localStore)
            try? manager.register(testProvider)
            return
        }
        #endif

        // 三个协议变体共享同一批模型与 API Key，仅保留功能最完整的 OpenAI 协议变体。
        // Anthropic / Responses 变体现注释停用（如需切换协议，取消注释即可）。
        let providers: [any SuperLLMProvider] = [MiniMaxOpenAIProvider(apiService: apiService, modelListCache: localStore)]
        // let providers: [any SuperLLMProvider] = [MiniMaxAnthropicProvider(apiService: apiService)]
        // let providers: [any SuperLLMProvider] = [MiniMaxResponsesProvider(apiService: apiService)]
        for provider in providers {
            if Self.verbose {
                let typeName = String(describing: type(of: provider))
                Self.logger.debug("\(Self.t)Registering provider: \(typeName, privacy: .public)")
            }
            try? manager.register(provider)
        }

        registerTokenPlanToolbarItem(kernel: kernel, manager: manager, apiService: apiService)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        selectionObserver?.cancel()
        selectionObserver = nil
        selectionGate = nil
        tokenPlanViewModel?.cancelPendingFetch()
        tokenPlanViewModel = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: Self.toolbarItemID)
    }

    // MARK: - Token Plan

    /// 注册 chat 工具栏配额 chip。
    ///
    /// chip 常驻注册、仅在选中 MiniMax 时渲染：把「是否展示」交给
    /// ``MiniMaxSelectionGate``，把「什么时候该拉数据」交给
    /// ``MiniMaxSelectionObserver`` 与 ViewModel 的 TTL 判定，避免在其它供应商下
    /// 既占用工具栏空间又触发无谓请求。
    private func registerTokenPlanToolbarItem(
        kernel: KernelCoreContainer,
        manager: any LLMManaging,
        apiService: VendorAPIService
    ) {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding; token plan toolbar item not registered")
            return
        }

        let viewModel = TokenPlanViewModel(
            apiService: apiService,
            apiKeyStorageKey: MiniMaxSharedConstants.apiKeyStorageKey
        )
        let gate = MiniMaxSelectionGate()
        tokenPlanViewModel = viewModel
        selectionGate = gate

        chat.addBarItems([
            ChatSectionBarItem(
                id: Self.toolbarItemID,
                order: 100,
                placement: .toolbarTrailing
            ) {
                TokenPlanQuotaGateView(gate: gate, viewModel: viewModel)
            },
        ])

        // 强引用保留观察者：LLM 选中态变化驱动 chip 可见性与首刷。
        let observer = MiniMaxSelectionObserver(
            manager: manager,
            gate: gate,
            onSelect: { [weak viewModel] in viewModel?.refreshIfNeeded() },
            onDeselect: { [weak viewModel] in viewModel?.cancelPendingFetch() }
        )
        selectionObserver = observer
        observer.start()
    }
}
