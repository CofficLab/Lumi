import LLMKit
import LumiCoreLLMProvider
import LumiKernel
import LumiUI

@MainActor
public final class LPgptPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.lpgpt"
    public let name = "LPgpt"
    public let order = 98
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // LLM Providers will be registered by old mechanism temporarily
        // TODO: Migrate to new registration method when available
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [LPgptProvider()]
    }
}
