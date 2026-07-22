import LLMKit
import LumiKernel
import LumiUI

@MainActor
public final class CodexLumiPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.codex"
    public let name = "Codex CLI"
    public let order = 105
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // LLM Providers will be registered by old mechanism temporarily
        // TODO: Migrate to new registration method when available
    }

    public func boot(kernel: LumiKernel) async throws {}
}
