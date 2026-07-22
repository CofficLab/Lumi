import LumiKernel
import os

@MainActor
public final class CodexPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.codex"
    public let name = "Codex"
    public let order = 105
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        for provider in llmProviders(kernel: kernel) {
            kernel.llmProvider?.registerLLMProvider(provider)
        }
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [CodexProvider()]
    }
}
