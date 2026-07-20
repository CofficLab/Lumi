import LLMKit
import LumiKernel
import LumiUI

@MainActor
public final class KimiCodePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.kimi-code"
    public let name = "Kimi Code"
    public let order = 103
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // LLM Providers will be registered by old mechanism temporarily
        // TODO: Migrate to new registration method when available
    }

    public func boot(kernel: LumiKernel) async throws {}
}
