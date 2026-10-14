import KitLLM
import Foundation
import ProviderLLMManager

/// MiniMax 供应商族：三个协议变体共用的模型列表。
enum MiniMaxVendorModels {
    static let all: [LLMModelInfo] = [
        LLMModelInfo(id: "MiniMax-M3.1-Flash-Preview", contextWindowSize: 1_000_000, supportsVision: true),
        LLMModelInfo(id: "MiniMax-M3", contextWindowSize: 1_000_000, supportsVision: true),
        LLMModelInfo(id: "MiniMax-M2.7", contextWindowSize: 204_800, supportsVision: true),
        LLMModelInfo(id: "MiniMax-M2.7-highspeed", contextWindowSize: 204_800, supportsVision: true),
        LLMModelInfo(id: "MiniMax-M2.5", contextWindowSize: 204_800, supportsVision: false),
        LLMModelInfo(id: "MiniMax-M2.5-highspeed", contextWindowSize: 204_800, supportsVision: false),
    ]
}

/// MiniMax TokenPlan OpenAI 协议变体（迁移自旧 `MiniMaxOpenAIProvider`）。
///
/// 模型列表获取策略：
/// 1. 远程模型池（国内站 `/v1/models`），需 API Key，可手动刷新。
/// 2. 插件自有磁盘缓存（`models.json`），跨启动保留，拉取失败时兜底。
/// 3. 下方 `MiniMaxVendorModels` 静态清单，含上下文窗口与视觉能力，完全无网时兜底。
///
/// 上游新增模型无需改本文件——刷新一次即可拿到。
@MainActor
public final class MiniMaxOpenAIProvider: VendorLLMProvider {

    // MARK: - 远程模型状态

    private let modelListCache: MiniMaxLocalStore
    private var fetchedRemoteModels: [LLMModelInfo] = []
    private var remoteSyncDate: Date?

    /// UI 测试钩子：非 nil 时刷新远程模型列表用它代替 Keychain 解析，
    /// 避免测试启动的 App 依赖用户真实 API Key。生产代码保持 nil。
    #if DEBUG
    var apiKeyOverride: String?
    #endif

    /// 使用纯内存缓存（不落盘）。仅供测试与 storage 缺失时降级。
    public convenience init(apiService: VendorAPIService = VendorAPIService()) {
        self.init(apiService: apiService, modelListCache: MiniMaxLocalStore())
    }

    /// 使用外部注入的模型列表缓存。
    ///
    /// - Parameters:
    ///   - apiService: 网络请求服务。
    ///   - modelListCache: 插件在 `onBoot` 中绑定好目录的 store；未绑定目录时退化为纯内存。
    init(
        apiService: VendorAPIService,
        modelListCache: MiniMaxLocalStore
    ) {
        self.modelListCache = modelListCache
        super.init(
            info: LLMProviderInfo(
                id: "minimax-tokenplan",
                displayName: "MiniMax",
                description: "MiniMax Token Plan via OpenAI-compatible API",
                defaultModel: "MiniMax-M2.7",
                models: MiniMaxVendorModels.all,
                websiteURL: URL(string: "https://platform.minimaxi.com/")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_MiniMax"
            ),
            apiService: apiService
        )
    }


    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.minimaxi.com/v1/chat/completions"
        )
    }

    // MARK: - SuperLLMProvider（远程模型逻辑）

    public override var usesRemoteModelList: Bool { true }

    public override var lastModelSyncDate: Date? { remoteSyncDate }

    /// 动态模型池：静态清单 ∪（远程快照 → 磁盘缓存）。
    ///
    /// 合并以静态清单为准（见 `MiniMaxRemoteModelListLoader.merge`），
    /// 保证上下文窗口与视觉能力不会因刷新而丢失。
    public override var availableModels: [LLMModelInfo] {
        let base = providerInfo.models

        let remote: [LLMModelInfo]
        if !fetchedRemoteModels.isEmpty {
            remote = fetchedRemoteModels
        } else if let cached = modelListCache.cachedSnapshot() {
            remote = cached.models
        } else {
            remote = []
        }

        return MiniMaxRemoteModelListLoader.merge(base: base, remote: remote)
    }

    /// 拉取国内站模型列表并更新内部快照与磁盘缓存。
    ///
    /// - Throws: 缺少 API Key / 请求或解析失败时抛错，**保留旧模型池**。
    public override func refreshModels() async throws {
        let loader = MiniMaxRemoteModelListLoader(apiService: apiService)
        let apiKey: String
        #if DEBUG
        if let apiKeyOverride {
            apiKey = apiKeyOverride
        } else {
            apiKey = try resolveAPIKey()
        }
        #else
        apiKey = try resolveAPIKey()
        #endif
        let models = try await loader.load(apiKey: apiKey)
        fetchedRemoteModels = models
        let now = Date()
        remoteSyncDate = now
        modelListCache.store(models: models, syncedAt: now)
    }
}

/// MiniMax Anthropic 协议变体（迁移自旧 `MiniMaxAnthropicProvider`）。
///
/// 已停用：与 OpenAI 变体共享同一批模型与 API Key，当前仅保留 OpenAI 变体。
/// 如需恢复，取消注释并在 MiniMaxProviderPlugin 中重新注册。
// @MainActor
// public final class MiniMaxAnthropicProvider: VendorLLMProvider {
//
//     public init(apiService: VendorAPIService = VendorAPIService()) {
//         super.init(
//             info: LLMProviderInfo(
//                 id: "minimax-tokenplan-anthropic",
//                 displayName: "MiniMax (Anthropic)",
//                 description: "MiniMax Token Plan via Anthropic-compatible API",
//                 defaultModel: "MiniMax-M2.7",
//                 models: MiniMaxVendorModels.all,
//                 websiteURL: URL(string: "https://platform.minimaxi.com/")!,
//                 apiFormat: .anthropic,
//                 apiKeyStorageKey: "DevAssistant_ApiKey_MiniMax"
//             ),
//             apiService: apiService
//         )
//     }
//
//
//     public override var anthropicConfiguration: AnthropicCompatibleProviderConfiguration? {
//         AnthropicCompatibleProviderConfiguration(
//             baseURL: "https://api.minimax.chat/anthropic/v1/messages"
//         )
//     }
// }

/// MiniMax Responses 协议变体（迁移自旧 `MiniMaxResponsesProvider`）。
///
/// 已停用：与 OpenAI 变体共享同一批模型与 API Key，当前仅保留 OpenAI 变体。
/// 如需恢复，取消注释并在 MiniMaxProviderPlugin 中重新注册。
// @MainActor
// public final class MiniMaxResponsesProvider: VendorLLMProvider {
//
//     public init(apiService: VendorAPIService = VendorAPIService()) {
//         super.init(
//             info: LLMProviderInfo(
//                 id: "minimax-responses",
//                 displayName: "MiniMax (Responses)",
//                 description: "MiniMax Token Plan via OpenAI Responses API",
//                 defaultModel: "MiniMax-M3",
//                 models: MiniMaxVendorModels.all,
//                 websiteURL: URL(string: "https://platform.minimaxi.com/")!,
//                 apiFormat: .responses,
//                 apiKeyStorageKey: "DevAssistant_ApiKey_MiniMax"
//             ),
//             apiService: apiService
//         )
//     }
//
//     public override var responsesEndpointURL: String {
//         "https://api.minimaxi.com/v1/responses"
//     }
//
// }
