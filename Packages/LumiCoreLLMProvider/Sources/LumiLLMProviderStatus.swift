import Foundation

public struct LumiLLMProviderStatus: Equatable, Sendable {
    public enum Level: Equatable, Sendable {
        case info
        case warning
        case error
    }

    public let message: String
    public let level: Level

    public init(message: String, level: Level) {
        self.message = message
        self.level = level
    }

    /// 是否为「阻塞级」状态：应当阻止依赖该 Provider 的功能（如子 Agent、相关 UI 工具）注册/暴露。
    ///
    /// - `nil` → 不阻塞（Provider 健康）。
    /// - `.info` → 不阻塞（仅作通知，不影响 Provider 实际可用性）。
    /// - `.warning` → **阻塞**（通常是 API Key 未配置、套餐过期等「能跑但跑不了」的情况，
    ///   调用方应拦截，避免把工具暴露给 LLM 后每次都失败）。
    /// - `.error` → **阻塞**（Provider 完全不可用，如 MLX 在 Intel Mac）。
    public var isBlocking: Bool {
        switch level {
        case .info:
            return false
        case .warning, .error:
            return true
        }
    }
}

public enum LumiLLMProviderStatusSupport {
    public static func missingAPIKeyStatus(providerName: String) -> LumiLLMProviderStatus {
        LumiLLMProviderStatus(
            message: "API Key not configured",
            level: .warning
        )
    }

    /// Default status for remote providers that require an API key.
    ///
    /// 必须传 `any LumiLLMProvider` 实例；存储策略由 Provider 自己决定。
    /// 不再提供 `providerInfo:` 重载：避免外部代码绕开 Provider 封装直接读存储键。
    public static func statusForRemoteAPIKeyProvider(
        provider: any LumiLLMProvider
    ) -> LumiLLMProviderStatus? {
        let info = type(of: provider).info
        guard !info.isLocal else { return nil }
        guard hasConfiguredAPIKey(provider: provider) else {
            return missingAPIKeyStatus(providerName: info.displayName)
        }
        return nil
    }

    /// 基于 `provider.hasApiKey()` 判定。
    public static func hasConfiguredAPIKey(provider: any LumiLLMProvider) -> Bool {
        provider.hasApiKey()
    }
}
