import LumiKernel
import os

@MainActor
public final class CodexPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.codex"
    public let name = "Codex"
    public let order = 105

    public init() {}

    public func register(kernel: LumiKernel) throws {}

    public func boot(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [CodexProvider()]
    }
}
