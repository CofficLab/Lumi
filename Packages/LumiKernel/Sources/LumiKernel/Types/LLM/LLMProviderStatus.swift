import Foundation

public struct LumiLLMProviderStatus: Sendable, Equatable {
    public let message: String
    public let level: Level
    public let isBlocking: Bool

    public init(message: String, level: Level, isBlocking: Bool = false) {
        self.message = message
        self.level = level
        self.isBlocking = isBlocking
    }

    public enum Level: Sendable, Equatable {
        case info
        case warning
        case error
    }
}

public enum LumiLLMProviderStatusSupport {
    public static func missingAPIKeyStatus(providerName: String) -> LumiLLMProviderStatus {
        LumiLLMProviderStatus(
            message: "\(providerName) API Key 未配置",
            level: .warning,
            isBlocking: true
        )
    }

    /// 基于「API Key 是否已配置」判定远程 provider 的状态。
    ///
    /// 远程 provider 的 `providerStatus()` 实现通常会委托到这里复用判定逻辑。
    /// 因此本方法**禁止**再回调 `provider.providerStatus()`(否则会形成
    /// `providerStatus() → statusForRemoteAPIKeyProvider → providerStatus()` 的
    /// 无限递归):判定只依赖 `hasApiKey()`,不再触碰 `providerStatus()`。
    ///
    /// - 已配置 Key → `nil`(健康,无状态可报告)
    /// - 未配置 Key → blocking `.warning`
    public static func statusForRemoteAPIKeyProvider(provider: LumiLLMProvider) -> LumiLLMProviderStatus? {
        // `info` 是协议的 `static var`,无法经 `any LumiLLMProvider` 实例直接访问,
        // 通过动态类型读取。
        provider.hasApiKey()
            ? nil
            : missingAPIKeyStatus(providerName: type(of: provider).info.displayName)
    }

    public static func hasConfiguredAPIKey(provider: LumiLLMProvider) -> Bool {
        provider.hasApiKey()
    }
}
