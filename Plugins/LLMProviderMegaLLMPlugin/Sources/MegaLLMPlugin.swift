import LLMKit
import LumiKernel
import LumiUI

@MainActor
public final class MegaLLMPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.megallm"
    public let name = "MegaLLM"
    public let order = 99

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // LLM Providers will be registered by old mechanism temporarily
        // TODO: Migrate to new registration method when available
    }

    public func boot(kernel: LumiKernel) async throws {}
}
