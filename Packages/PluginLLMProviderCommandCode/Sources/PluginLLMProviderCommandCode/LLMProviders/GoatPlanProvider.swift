import KitLLM
import Foundation
import ProviderLLMManager

/// CommandCode GoatPlan 供应商（OpenAI 兼容协议）。
///
/// 通过 CommandCode 统一网关访问多种模型，使用 OpenAI Chat Completions 格式。
///
/// 模型列表获取策略（由本插件自行决定）：
/// 1. 远程模型池（`/provider/v1/models`），由 KitLLM loader 解析并缓存。
/// 2. 磁盘缓存，跨启动保留，拉取失败时兜底。
/// 3. 下方 `providerInfo.models` 中硬编码的完整模型清单，完全无网时兜底。
///
/// 上游加模型无需改本文件——刷新一次即可拿到新模型池。
/// 若需要自定义解析/刷新逻辑，直接 override `refreshModels()` 即可。
@MainActor
public final class GoatPlanProvider: VendorLLMProvider {

    // MARK: - 远程模型状态（本插件自行管理）

    private let modelListCache: LLMModelListCache
    private var fetchedRemoteModels: [LLMModelInfo] = []
    private var remoteSyncDate: Date?

    /// 远程模型源：CommandCode `/provider/v1/models` 端点。
    ///
    /// 该端点无需鉴权（公开可读），故不配 `apiKeyStorageKey`——
    /// 也避免后台刷新时读 Keychain（无头环境可能挂起）。
    private let remoteModelSource: RemoteModelSource = RemoteModelSource(
        endpoint: URL(string: "https://api.commandcode.ai/provider/v1/models")!
    )

    public init(apiService: VendorAPIService = VendorAPIService()) {
        self.modelListCache = LLMModelListCache(providerID: "goatplan")
        super.init(
            info: LLMProviderInfo(
                id: "goatplan",
                displayName: "CommandCode GoatPlan",
                description: "CommandCode GoatPlan 多模型订阅服务",
                defaultModel: "deepseek/deepseek-v4-flash",
                models: [
                    // Claude
                    LLMModelInfo(id: "claude-sonnet-5", displayName: "Claude Sonnet 5", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "claude-sonnet-4-6", displayName: "Claude Sonnet 4.6", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "claude-fable-5-1", displayName: "Claude Fable 5.1", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "claude-fable-5", displayName: "Claude Fable 5", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "claude-opus-5", displayName: "Claude Opus 5", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "claude-opus-4-8", displayName: "Claude Opus 4.8", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "claude-opus-4-7", displayName: "Claude Opus 4.7", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "claude-haiku-4-5-20251001", displayName: "Claude Haiku 4.5", contextWindowSize: 200_000),
                    // GPT
                    LLMModelInfo(id: "gpt-5.6-sol", displayName: "GPT-5.6 Sol", contextWindowSize: 1_050_000),
                    LLMModelInfo(id: "gpt-5.6-terra", displayName: "GPT-5.6 Terra", contextWindowSize: 1_050_000),
                    LLMModelInfo(id: "gpt-5.6-luna", displayName: "GPT-5.6 Luna", contextWindowSize: 1_050_000),
                    LLMModelInfo(id: "gpt-5.5", displayName: "GPT-5.5", contextWindowSize: 400_000),
                    LLMModelInfo(id: "gpt-5.4", displayName: "GPT-5.4", contextWindowSize: 400_000),
                    LLMModelInfo(id: "gpt-5.3-codex", displayName: "GPT-5.3 Codex", contextWindowSize: 400_000),
                    LLMModelInfo(id: "gpt-5.4-mini", displayName: "GPT-5.4 Mini", contextWindowSize: 400_000),
                    // DeepSeek
                    LLMModelInfo(id: "deepseek/deepseek-v4-pro", displayName: "DeepSeek V4 Pro", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "deepseek/deepseek-v4-flash", displayName: "DeepSeek V4 Flash", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "deepseek/deepseek-v4-flash-vision-exp", displayName: "DeepSeek V4 Flash Vision", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "deepseek/deepseek-v4-flash-fast", displayName: "DeepSeek V4 Flash Fast", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "deepseek/deepseek-v4.1-flash", displayName: "DeepSeek V4.1 Flash", contextWindowSize: 1_000_000, supportsVision: true),
                    // Kimi
                    LLMModelInfo(id: "moonshotai/Kimi-K3", displayName: "Kimi K3", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "moonshotai/Kimi-K2.7-Code", displayName: "Kimi K2.7 Code", contextWindowSize: 256_000),
                    LLMModelInfo(id: "moonshotai/Kimi-K2.7-Code-Highspeed", displayName: "Kimi K2.7 Code HighSpeed", contextWindowSize: 262_000),
                    LLMModelInfo(id: "moonshotai/Kimi-K2.6", displayName: "Kimi K2.6", contextWindowSize: 256_000),
                    LLMModelInfo(id: "moonshotai/Kimi-K2.5", displayName: "Kimi K2.5", contextWindowSize: 256_000),
                    // GLM
                    LLMModelInfo(id: "z-ai/glm-5.3-flash", displayName: "GLM-5.3 Flash", contextWindowSize: 1_048_576),
                    LLMModelInfo(id: "zai-org/GLM-5.3", displayName: "GLM-5.3", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "zai-org/GLM-5.2", displayName: "GLM-5.2", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "zai-org/GLM-5.2-Fast", displayName: "GLM-5.2 Fast", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "zai-org/GLM-5.1", displayName: "GLM-5.1", contextWindowSize: 200_000),
                    LLMModelInfo(id: "zai-org/GLM-5", displayName: "GLM-5", contextWindowSize: 200_000),
                    // MiniMax
                    LLMModelInfo(id: "MiniMaxAI/MiniMax-M3", displayName: "MiniMax M3", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "MiniMaxAI/MiniMax-M2.7", displayName: "MiniMax M2.7", contextWindowSize: 200_000),
                    LLMModelInfo(id: "MiniMaxAI/MiniMax-M2.5", displayName: "MiniMax M2.5", contextWindowSize: 200_000),
                    // MiMo
                    LLMModelInfo(id: "xiaomi/mimo-v2.5-pro", displayName: "MiMo V2.5 Pro", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "xiaomi/mimo-v2.5", displayName: "MiMo V2.5", contextWindowSize: 1_000_000),
                    // Qwen
                    LLMModelInfo(id: "Qwen/Qwen3.8-Max-0902", displayName: "Qwen 3.8 Max 0902", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "Qwen/Qwen3.8-Max", displayName: "Qwen 3.8 Max", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "Qwen/Qwen3.8-27B", displayName: "Qwen 3.8 27B", contextWindowSize: 262_144),
                    LLMModelInfo(id: "Qwen/Qwen3.8-Flash", displayName: "Qwen 3.8 Flash", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "Qwen/Qwen3.7-Max", displayName: "Qwen 3.7 Max", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "Qwen/Qwen3.7-Plus", displayName: "Qwen 3.7 Plus", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "Qwen/Qwen3.7-Flash", displayName: "Qwen 3.7 Flash", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "Qwen/Qwen3.6-Max-Preview", displayName: "Qwen 3.6 Max Preview", contextWindowSize: 200_000),
                    LLMModelInfo(id: "Qwen/Qwen3.6-Plus", displayName: "Qwen 3.6 Plus", contextWindowSize: 200_000),
                    // Step
                    LLMModelInfo(id: "stepfun/Step-3.7-Flash", displayName: "Step 3.7 Flash", contextWindowSize: 256_000),
                    LLMModelInfo(id: "stepfun/Step-3.5-Flash", displayName: "Step 3.5 Flash", contextWindowSize: 1_000_000),
                    // Tencent
                    LLMModelInfo(id: "tencent/hy3-paid", displayName: "Tencent Hy3", contextWindowSize: 262_144),
                    LLMModelInfo(id: "tencent/hy4-preview", displayName: "Tencent Hy4 Preview", contextWindowSize: 1_048_576),
                    // Gemini
                    LLMModelInfo(id: "google/gemini-3.8-flash", displayName: "Gemini 3.8 Flash", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "google/gemini-3.7-flash", displayName: "Gemini 3.7 Flash", contextWindowSize: 1_048_576),
                    LLMModelInfo(id: "google/gemini-3.6-flash", displayName: "Gemini 3.6 Flash", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "google/gemini-3.5-flash", displayName: "Gemini 3.5 Flash", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "google/gemini-3.5-flash-lite", displayName: "Gemini 3.5 Flash Lite", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "google/gemini-3.1-flash-lite", displayName: "Gemini 3.1 Flash Lite", contextWindowSize: 1_000_000),
                    // Others
                    LLMModelInfo(id: "meituan/LongCat-2.0:free", displayName: "LongCat 2.0", contextWindowSize: 1_048_576),
                    LLMModelInfo(id: "sakana/fugu-ultra", displayName: "Fugu Ultra", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "nvidia/nemotron-3-ultra-550b-a55b", displayName: "Nemotron 3 Ultra", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "thinkingmachines/inkling", displayName: "Inkling", contextWindowSize: 256_000),
                    LLMModelInfo(id: "thinkingmachines/inkling-small", displayName: "Inkling Small", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "poolside/laguna-s-2.1-free", displayName: "Laguna S 2.1", contextWindowSize: 262_144),
                    LLMModelInfo(id: "inclusionai/ling-3.0-flash-sante:free", displayName: "Ling 3.0 Flash Sante", contextWindowSize: 262_144),
                    // Muse Spark
                    LLMModelInfo(id: "meta/muse-spark-1.1", displayName: "Muse Spark 1.1", contextWindowSize: 1_048_576),
                    LLMModelInfo(id: "meta/muse-spark-1.2", displayName: "Muse Spark 1.2", contextWindowSize: 1_048_576),
                    LLMModelInfo(id: "meta/muse-spark-1.2-contributor", displayName: "Muse Spark 1.2 Contributor", contextWindowSize: 1_048_576),
                    LLMModelInfo(id: "meta/muse-spark-1.3", displayName: "Muse Spark 1.3", contextWindowSize: 1_048_576),
                    LLMModelInfo(id: "meta/muse-spark-1.3-contributor", displayName: "Muse Spark 1.3 Contributor", contextWindowSize: 1_048_576),
                    // Grok
                    LLMModelInfo(id: "xai/grok-4.5", displayName: "Grok 4.5", contextWindowSize: 500_000),
                    LLMModelInfo(id: "xai/grok-4.6", displayName: "Grok 4.6", contextWindowSize: 500_000),
                ],
                websiteURL: URL(string: "https://commandcode.ai")!,
                providerType: .cloudService,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_CommandCodeGoatPlan"
            ),
            apiService: apiService
        )
    }

    // MARK: - SuperLLMProvider（远程模型逻辑，本插件自行实现）

    public override var usesRemoteModelList: Bool { true }

    public override var lastModelSyncDate: Date? { remoteSyncDate }

    /// 动态模型池：静态基线 ∪（远程快照 → 磁盘缓存）。
    ///
    /// - 远程优先（保留远程的 displayName / contextWindowSize）
    /// - 静态基线兜底补齐（保证永不为空）
    /// - 排序：先静态声明顺序，远程新增模型追加在后
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

        return RemoteModelMerger.merge(base: base, remote: remote)
    }

    /// 拉取远程模型端点并更新内部快照与缓存。
    ///
    /// - Throws: 拉取/解析失败时抛错，**保留旧模型池**（调用方无需回滚）。
    public override func refreshModels() async throws {
        let loader = RemoteModelListLoader(apiService: apiService)
        let models = try await loader.load(from: remoteModelSource, apiKey: nil)
        fetchedRemoteModels = models
        let now = Date()
        remoteSyncDate = now
        modelListCache.store(models: models, syncedAt: now)
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.commandcode.ai/provider/v1/chat/completions"
        )
    }
}
