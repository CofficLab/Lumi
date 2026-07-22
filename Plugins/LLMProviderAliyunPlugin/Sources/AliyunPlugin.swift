import LLMKit
import LumiKernel
import LumiKernel
import LumiKernel
import LumiUI

@MainActor
public final class AliyunPlugin: LumiPlugin {
    public static let rendererOrder = 305

    public let id = "com.coffic.lumi.plugin.llm-provider.aliyun"
    public let name = "阿里云 CodingPlan"
    public let order = 105
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        for provider in llmProviders(kernel: kernel) {
            kernel.llmProvider?.registerLLMProvider(provider)
        }
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [AliyunProvider()]
    }
}
