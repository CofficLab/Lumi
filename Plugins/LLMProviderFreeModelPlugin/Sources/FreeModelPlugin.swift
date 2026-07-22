import LLMKit
import LumiKernel
import LumiKernel
import LumiUI

@MainActor
public final class FreeModelPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.freemodel"
    public let name = "FreeModel"
    public let order = 95
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        for provider in llmProviders(kernel: kernel) {
            kernel.llmProvider?.registerLLMProvider(provider)
        }
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [FreeModelProvider()]
    }
}
