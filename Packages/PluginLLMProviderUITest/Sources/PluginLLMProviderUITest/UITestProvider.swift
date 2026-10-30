import Foundation
import KitLLM

/// UI 测试专用供应商。
///
/// ## 存在理由
///
/// 真实供应商在 UI 测试里有三个不可控因素：网络、用户 API Key、模型自身的
/// 不确定性（回复内容与长度不可预期）。这三个因素会让「点击发送后界面应该
/// 变成什么样」这类断言无法写死。
///
/// 本供应商消除它们：字节流由桩决定、Key 是固定串、回复内容由模型名决定。
/// 测试因此可以断言**具体的界面终态**，而不只是「好像开始请求了」。
///
/// ## 与 MiniMax 夹具的关系（两者互补，不是替代）
///
/// - MiniMax 夹具（`--lumi-ui-testing`）桩在传输层，**保留真实供应商实例**，
///   用来测供应商自身特性（远程模型池刷新、合并策略）。
/// - 本供应商替换整个供应商对象，覆盖「AgentLoop → 消息渲染 → 工具执行」
///   这段 MiniMax 夹具不适合覆盖的链路。
///
/// 两者共用 `--lumi-ui-testing` 启动参数，可同时生效。
///
/// ## 与真实供应商的差异（有意为之）
///
/// - `isLocal: true` —— 归入模型选择器的「本地」分组，不与云端供应商混排，
///   也不触发「未配置 API Key」的提示。
/// - `resolveAPIKey()` 返回固定串 —— 完全绕开 Keychain。真实供应商读 Keychain
///   在测试环境下可能弹权限授权框，会阻塞 UI 测试。
@MainActor
public final class UITestProvider: VendorLLMProvider {

    /// 固定假 Key。仅用于满足 `Authorization` header，桩网络不做任何校验。
    ///
    /// 不写入 Keychain，也不从 Keychain 读取。
    public static let stubAPIKey = "ui-test-key"

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: UITestProvider.providerID,
                displayName: "UI Test",
                description: "Deterministic provider for UI tests",
                defaultModel: UITestScenario.defaultModel.rawValue,
                models: UITestScenario.allModels,
                isLocal: true,
                websiteURL: nil,
                providerType: .local,
                apiFormat: .openAI,
                // 本供应商从不用 Keychain；留一个专属 key 仅为避免与其他供应商冲突。
                apiKeyStorageKey: "DevAssistant_ApiKey_UITest"
            ),
            apiService: apiService
        )
    }

    /// 供应商注册表 key。与 `PluginUITestProviderPlugin.providerID` 保持一致。
    public static let providerID = "ui-test"

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            // 桩网络在传输层拦截，这个 URL 永远不会被真正请求。
            baseURL: "https://ui-test.invalid/v1/chat/completions"
        )
    }

    // MARK: - SuperLLMProvider

    /// 返回固定假 Key，绕开 Keychain 访问。
    ///
    /// - Important: 不能依赖协议扩展的默认实现——那会读 Keychain 并在未配置时
    ///   抛 `missingAPIKey`，导致 UI 测试稳定失败。也不能只 `hasApiKey()` 返回
    ///   true：真实调用路径走的是 `resolveAPIKey()`。
    public override func resolveAPIKey() throws -> String {
        Self.stubAPIKey
    }

    public override func getApiKey() -> String {
        Self.stubAPIKey
    }

    public override func hasApiKey() -> Bool { true }

    /// 写 Key 是 no-op：测试环境不应污染 Keychain。
    public override func setApiKey(_ apiKey: String) {}

    /// 删 Key 是 no-op：本供应商从不持有 Key。
    public override func removeApiKey() {}

    /// 静态模型池：无远程源，由 `providerInfo.models` 提供。
    ///
    /// 默认实现已经如此，显式覆写是为了让「本供应商没有远程模型列表」这一
    /// 契约在代码里可见——UI 测试点击「刷新模型」应是无副作用的空操作。
    public override var usesRemoteModelList: Bool { false }
}
