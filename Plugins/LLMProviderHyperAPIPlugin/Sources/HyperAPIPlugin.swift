import LLMKit
import LumiKernel
import LumiUI

@MainActor
public final class HyperAPIPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.hyperapi"
    public let name = "HyperAPI"
    public let order = 97

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // LLM Providers will be registered by old mechanism temporarily
        // TODO: Migrate to new registration method when available
    }

    public func boot(kernel: LumiKernel) async throws {}
}
