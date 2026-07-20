import LLMKit
import LumiCoreLLMProvider
import LumiKernel
import LumiUI

@MainActor
public final class DeepSeekPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.deepseek"
    public let name = "DeepSeek"
    public let order = 92

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // LLM Providers will be registered by old mechanism temporarily
        // TODO: Migrate to new registration method when available
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [DeepSeekProvider()]
    }
}
