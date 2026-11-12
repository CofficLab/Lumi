import KitLLM
import Foundation
import ProviderLLMManager

/// MiniMax 供应商族：三个协议变体共用的模型列表。
///
/// 元数据来源（2026-11 实测国内站 `GET /v1/models` + 官方文档）：
/// - **可用语言模型只有两个**：`MiniMax-M3.1-Flash` 与 `MiniMax-M3`。
///   官方《模型列表》把 M2 / M2.1 / M2.5 / M2.7 全系列标为「已下线」，
///   其中 M2.5 / M2.7 系列**正式下线日为 2026-11-18**。
/// - 上下文窗口：官方文档标注 M3 系列为 1,000,000。
/// - 视觉能力：官方文档明确「仅 M3 / M3.1-Flash 支持图片」输入。
///
/// - Important: id 必须与上游 `/v1/models` **完全一致**，否则远程刷新后
///   会出现「清单里的旧 id」与「远程的真实 id」两个条目并存。历史清单里的
///   `MiniMax-M3.1-Flash-Preview` 并不存在（真实 id 是 `MiniMax-M3.1-Flash`），
///   已修正。
enum MiniMaxVendorModels {
    static let all: [LLMModelInfo] = [
        LLMModelInfo(id: "MiniMax-M3.1-Flash", contextWindowSize: 1_000_000, supportsVision: true),
        LLMModelInfo(id: "MiniMax-M3", contextWindowSize: 1_000_000, supportsVision: true),
    ]
}

/// MiniMax TokenPlan OpenAI 协议变体（迁移自旧 `MiniMaxOpenAIProvider`）。
///
/// 模型列表获取策略：
/// 1. 远程模型池（国内站 `/v1/models`），需 API Key，可手动刷新。
/// 2. 插件自有磁盘缓存（`models.json`），跨启动保留，拉取失败时兜底。
/// 3. 下方 `MiniMaxVendorModels` 静态清单，含上下文窗口与视觉能力，完全无网时兜底。
///
/// 上游新增模型无需改本文件——刷新一次即可拿到。远程返回的 id 会经
/// ``MiniMaxModelFamily`` 按家族补全上下文窗口与视觉能力（上游接口不返回
/// 这两项），因此新模型不会退化成 32K 兜底预算。
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
                defaultModel: "MiniMax-M3.1-Flash",
                models: MiniMaxVendorModels.all,
                websiteURL: URL(string: "https://platform.minimaxi.com/")!,
                apiFormat: .openAI,
                apiKeyStorageKey: MiniMaxSharedConstants.apiKeyStorageKey,
                // 轻量任务模型：对话标题、上下文摘要等幕后调用用它，
                // 而不是消耗对话主模型的额度。
                //
                // 选 M3.1-Flash 的依据（2026-11 官方定价页）：
                // 输入 ¥1.00/M、输出 ¥4.00/M、缓存读取 ¥0.10/M，
                // 而 M3 是 ¥2.10 / ¥8.40 / ¥0.42——便宜约 2.1 倍。
                //
                // 注意：M3.1-Flash 的思考深度**不可关闭**，标题这类短请求
                // 也会带上思考 token；正文与思考内容在响应里是分开解析的
                // （`content` vs `reasoning_content`），不会污染标题。
                recommendedUtilityModel: "MiniMax-M3.1-Flash"
            ),
            apiService: apiService
        )
    }


    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.minimaxi.com/v1/chat/completions",
            // MiniMax 的 effort 档位比 OpenAI 兼容基线多两档（见官方文档
            // 「Thinking depth」），不透传会让用户在 UI 选中的 xhigh / max
            // 被静默丢弃。
            additionalReasoningEfforts: ["xhigh", "max"]
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
//                 defaultModel: "MiniMax-M3.1-Flash",
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
