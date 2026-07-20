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
        // LLM Providers will be registered by old mechanism temporarily
        // TODO: Migrate to new registration method when available
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [ZhipuProvider()]
    }
}
