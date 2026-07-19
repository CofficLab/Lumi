import LLMKit
import LumiKernel
import LumiUI

@MainActor
public final class HappyCodePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.happycode"
    public let name = "HappyCode"
    public let order = 96

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // LLM Providers will be registered by old mechanism temporarily
        // TODO: Migrate to new registration method when available
    }

    public func boot(kernel: LumiKernel) async throws {}
}
