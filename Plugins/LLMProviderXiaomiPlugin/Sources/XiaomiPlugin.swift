import LLMKit
import LumiKernel
import LumiKernel
import LumiUI

@MainActor
public final class XiaomiPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.xiaomi"
    public let name = "Xiaomi"
    public let order = 102
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        for provider in llmProviders(kernel: kernel) {
            kernel.llmProvider?.registerLLMProvider(provider)
        }
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [XiaomiProvider()]
    }
}
