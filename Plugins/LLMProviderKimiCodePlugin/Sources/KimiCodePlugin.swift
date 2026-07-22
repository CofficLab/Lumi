import LLMKit
import LumiKernel
import LumiKernel
import LumiKernel
import LumiUI

@MainActor
public final class KimiCodePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.kimi-code"
    public let name = "Kimi Code"
    public let order = 103
	public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        for provider in llmProviders(kernel: kernel) {
            kernel.llmProvider?.registerLLMProvider(provider)
        }
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [KimiCodeOpenAIProvider(), KimiCodeAnthropicProvider()]
    }
}
