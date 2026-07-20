import LLMKit
import LumiCoreLLMProvider
import LumiKernel
import LumiUI

@MainActor
public final class XiaomiPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.xiaomi"
    public let name = "Xiaomi"
    public let order = 102

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // LLM Providers will be registered by old mechanism temporarily
        // TODO: Migrate to new registration method when available
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [XiaomiProvider()]
    }
}
