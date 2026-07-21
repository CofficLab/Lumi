import LLMKit
import LumiCoreLLMProvider
import LumiKernel
import LumiUI

@MainActor
public final class ZhipuPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.zhipu"
    public let name = "智谱 Coding Plan"
    public let order = 110
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        for provider in llmProviders(kernel: kernel) {
            kernel.llmProvider?.registerLLMProvider(provider)
        }
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [ZhipuProvider()]
    }
}
