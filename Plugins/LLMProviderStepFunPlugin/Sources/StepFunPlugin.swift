import LLMKit
import LumiCoreKit
import LumiCoreKit
import os
import SuperLogKit

public enum StepFunPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.stepfun")
    public nonisolated static let emoji = "🌟"
    public static var verbose: Bool { false }
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.stepfun",
        displayName: LumiPluginLocalization.string("StepFun StepPlan", bundle: .module),
        description: LumiPluginLocalization.string("Contributes StepFun StepPlan models to Lumi Chat.", bundle: .module),
        order: 93,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        if let core = context.lumiCore {
            AvailabilityDiskCacheDirectoryResolver.set(pluginName: "LLMProviderStepFunPlugin", directory: core.storage.pluginDataDirectory(for: "LLMProviderStepFunPlugin"))
        }
        return [StepFunProvider()]
    }

    @MainActor
    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        ProviderRenderKindManager.shared.registerProviderPrefix("stepfun-", for: StepFunProvider.info.id)
        return [
            ApiKeyMissingRenderer.item,
            Http401Renderer.item,
            Http403Renderer.item,
            HttpErrorRenderer.item,
            RequestFailedRenderer.item,
        ]
    }

    @MainActor
    public static func subAgents(context: LumiPluginContext) -> [LumiSubAgentDefinition] {
        if Self.verbose {
            logger.info("\(Self.t)开始注册子 Agent")
        }

        // Provider 可用性 gate：所有子 Agent 都绑定 StepFunProvider 模型推理。
        // 若该 Provider 当前不可用（如未配置 API Key、套餐过期、运行时被禁用），
        // 主 LLM 调 delegate_* 后会在每次调用时才拿到 "Provider not available" 错误，
        // 既浪费 token 又污染上下文。这里在注册期直接 gate，返回空数组
        // 让主 LLM 看不到这些工具，退化到手动串普通工具链。
        guard isStepFunProviderAvailable(context: context) else {
            if Self.verbose {
                logger.info("\(Self.t)Provider 不可用，跳过所有子 Agent 注册")
            }
            return []
        }

        let agents = [
            GitCommitWriterAgent.definition,
            CodeReviewAgent.definition,
            TestWriterAgent.definition,
            DocWriterAgent.definition,
            BugFixerAgent.definition,
            XcodeBuildAgent.definition,
        ]
        if Self.verbose {
            logger.info("\(Self.t)子 Agent 注册完成，共 \(agents.count) 个：\(agents.map(\.id).joined(separator: ", "))")
        }
        return agents
    }

    /// 检查 StepFunProvider 当前是否可用。
    ///
    /// 使用 `LumiLLMProviderStatus.isBlocking` 作为单一判定：
    /// `nil` 或 `.info` 级别视为可用；`.warning`/`.error` 视为阻塞。
    /// 这样 API Key 缺失、套餐过期、平台不兼容等情况都会自动跳过子 Agent 注册。
    @MainActor
    private static func isStepFunProviderAvailable(context: LumiPluginContext) -> Bool {
        if Self.verbose {
            logger.info("\(Self.t)检查 StepFunProvider 可用性")
        }
        guard let chatService = context.resolve((any LumiChatServicing).self) else {
            // 没有 ChatService 时（极早期阶段）保守返回 false，避免注册了用不了
            Self.logSkip(reason: "no ChatService in plugin context")
            return false
        }
        guard let provider = chatService.provider(forID: StepFunProvider.info.id) else {
            Self.logSkip(reason: "StepFunProvider instance not found in chatService")
            return false
        }
        if let status = provider.providerStatus(), status.isBlocking {
            Self.logSkip(
                reason: "StepFunProvider blocking status [\(status.level)] — \(status.message)"
            )
            return false
        }
        if Self.verbose {
            logger.info("\(Self.t)StepFunProvider 可用，允许注册子 Agent")
        }
        return true
    }

    /// 记录「跳过子 Agent 注册」的原因。仅在 verbose 开启时写磁盘，避免噪音。
    private static func logSkip(reason: String) {
        guard verbose else { return }
        logger.info("\(Self.t)skip sub-agent registration: \(reason, privacy: .public)")
    }
}
