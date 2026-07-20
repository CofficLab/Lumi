import LLMKit
import LumiCoreLLMProvider
import LumiCoreMessage
import LumiKernel
import LumiUI

@MainActor
public final class AliyunPlugin: LumiPlugin {
    public static let rendererOrder = 305

    public let id = "com.coffic.lumi.plugin.llm-provider.aliyun"
    public let name = "阿里云 CodingPlan"
    public let order = 105

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // LLM Providers will be registered by old mechanism temporarily
        // TODO: Migrate to new registration method when available
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [AliyunProvider()]
    }
}
