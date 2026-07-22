import LLMKit
import LumiKernel
import LumiKernel
import LumiUI

@MainActor
public final class HyperAPIPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.hyperapi"
    public let name = "HyperAPI"
    public let order = 97
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        for provider in llmProviders(kernel: kernel) {
            kernel.llmProvider?.registerLLMProvider(provider)
        }
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [HyperAPIProvider()]
    }
}
