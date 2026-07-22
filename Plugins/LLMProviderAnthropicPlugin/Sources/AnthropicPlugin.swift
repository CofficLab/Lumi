import LLMKit
import LumiKernel
import LumiKernel
import LumiUI

@MainActor
public final class AnthropicPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.anthropic"
    public let name = "Anthropic"
    public let order = 104
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        for provider in llmProviders(kernel: kernel) {
            kernel.llmProvider?.registerLLMProvider(provider)
        }
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [AnthropicProvider()]
    }
}
