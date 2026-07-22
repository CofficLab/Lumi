import LLMKit
import LumiKernel
import LumiKernel
import LumiUI

@MainActor
public final class DeepSeekPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.deepseek"
    public let name = "DeepSeek"
    public let order = 92
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        for provider in llmProviders(kernel: kernel) {
            kernel.llmProvider?.registerLLMProvider(provider)
        }
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [DeepSeekProvider()]
    }
}
