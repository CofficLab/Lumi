import LLMKit
import LumiKernel
import LumiKernel
import LumiUI

@MainActor
public final class HappyCodePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.happycode"
    public let name = "HappyCode"
    public let order = 96
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        for provider in llmProviders(kernel: kernel) {
            kernel.llmProvider?.registerLLMProvider(provider)
        }
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [HappyCodeProvider()]
    }
}
